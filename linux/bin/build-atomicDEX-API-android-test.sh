#!/usr/bin/env bash
# (c) Decker 2022

# --------------------------------------------------------------------------
function init_colors() {
    RESET="\033[0m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    BRIGHT="\033[1m"
    DARKGREY="\033[90m"
}
# --------------------------------------------------------------------------
function log_print() {
   datetime=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e [$datetime] $1 | tee --append $LOGFILE
   
}

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# LOGFILE="${SCRIPTPATH}/${0##*/}.log"
LOGFILE="/tmp/${0##*/}.log"
WORKSPACE=$(pwd)
# chmod o+w ${LOGFILE}

init_colors
log_print "Script path: ${SCRIPTPATH}"
log_print "Log file: ${LOGFILE}"
log_print "Workspace path: ${WORKSPACE}"
log_print "Starting build ..."

###
Agent_OS=android
AGENT_OS=${Agent_OS}
Build_BuildId=${BUILD_ID}
Build_SourceBranchName=${GIT_BRANCH:7} # cut off 'origin/' from the begin
COMMIT_HASH=${GIT_COMMIT:0:9}
###

### Setup ENV
export SHORT_HASH="$(git rev-parse --short=9 HEAD)"
echo "##vso[task.setvariable variable=COMMIT_HASH]${SHORT_HASH}"
export TAG="$(git tag -l --points-at HEAD)"
echo "##vso[task.setvariable variable=COMMIT_TAG]${TAG}"
if [ -z $TAG ]; then
echo "Commit tag is empty"
export RELEASE_TAG=beta-2.1.${Build_BuildId}
else
export DEBUG_UPLOADED="$(curl -s https://api.github.com/repos/KomodoPlatform/atomicDEX-API/releases/tags/$TAG | grep ${Agent_OS}-Debug)"
export RELEASE_UPLOADED="$(curl -s https://api.github.com/repos/KomodoPlatform/atomicDEX-API/releases/tags/$TAG | grep ${Agent_OS}-Release)"
export RELEASE_TAG=$TAG
fi
echo DEBUG_UPLOADED:$DEBUG_UPLOADED
echo RELEASE_UPLOADED:$RELEASE_UPLOADED
echo RELEASE_TAG:$RELEASE_TAG
echo "##vso[task.setvariable variable=DEBUG_UPLOADED]${DEBUG_UPLOADED}"
echo "##vso[task.setvariable variable=RELEASE_UPLOADED]${RELEASE_UPLOADED}"
echo "##vso[task.setvariable variable=RELEASE_TAG]${RELEASE_TAG}"

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

### Prepare common container for build Android armv7 and aarch64
# export UID=$(id -u) # read only variable
export GID=$(id -g)

docker build -f ${SCRIPTPATH}/Dockerfile.android.ci --build-arg BUILDER_NAME=$USER --build-arg BUILDER_UID=$(id -u) --build-arg BUILDER_GID=$(id -g) -t mm2_android_builder .

mkdir -p -v /home/$USER/.cargo/git
mkdir -p -v /home/$USER/.cargo/registry

# --- (1) armv7 build ---
rm -f MM_VERSION
VERSION=2.1.${Build_BuildId}_${Build_SourceBranchName}_${COMMIT_HASH}_${Agent_OS}_armv7_CI
if ! grep -q $VERSION MM_VERSION; then
echo $VERSION > MM_VERSION
fi
cat MM_VERSION
touch mm2src/common/build.rs

# printenv > ${LOGFILE}
# https://stackoverflow.com/questions/73105626/arm-linux-androideabi-ar-command-not-found-in-ndk

docker run \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    -v /home/$USER/.cargo/git:/root/.cargo/git \
    -v /home/$USER/.cargo/registry:/root/.cargo/registry \
    -v $PWD:$PWD \
    -w $PWD \
    -e HOME=/root \
    -e AR_armv7_linux_androideabi=llvm-ar \
    -e CC_armv7_linux_androideabi=armv7a-linux-androideabi21-clang \
    -e CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER=armv7a-linux-androideabi21-clang \
    mm2_android_builder \
    /bin/bash -c "rustup override set nightly-2022-10-29 && cargo rustc --target=armv7-linux-androideabi --lib --profile release --crate-type=staticlib --package mm2_main"

#mv target/armv7-linux-androideabi/release/libmm2.a target/armv7-linux-androideabi/release/libmm2.a
mv target/armv7-linux-androideabi/release/libmm2_main.a target/armv7-linux-androideabi/release/libmm2.a
zip upload/mm2-${COMMIT_HASH}-${Agent_OS}-armv7-CI target/armv7-linux-androideabi/release/libmm2.a -j

# --- (2) aarch64 build ---
rm -f MM_VERSION
VERSION=2.1.${Build_BuildId}_${Build_SourceBranchName}_${COMMIT_HASH}_${Agent_OS}_aarch64_CI
if ! grep -q $VERSION MM_VERSION; then
echo $VERSION > MM_VERSION
fi
cat MM_VERSION
touch mm2src/common/build.rs

# printenv > ${LOGFILE}

docker run \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    -v /home/$USER/.cargo/git:/root/.cargo/git \
    -v /home/$USER/.cargo/registry:/root/.cargo/registry \
    -v $PWD:$PWD \
    -w $PWD \
    -e HOME=/root \
    -e AR_aarch64_linux_android=llvm-ar \
    -e CC_aarch64_linux_android=aarch64-linux-android21-clang \
    -e CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=aarch64-linux-android21-clang \
    mm2_android_builder \
    /bin/bash -c "rustup override set nightly-2022-10-29 && cargo rustc --target=aarch64-linux-android --lib --profile release --crate-type=staticlib --package mm2_main"

# mv target/aarch64-linux-android/ci/libmm2lib.a target/aarch64-linux-android/ci/libmm2.a
mv target/aarch64-linux-android/release/libmm2_main.a target/aarch64-linux-android/release/libmm2.a
zip upload/mm2-${COMMIT_HASH}-${Agent_OS}-aarch64-CI target/aarch64-linux-android/release/libmm2.a -j

log_print "Build end ..."