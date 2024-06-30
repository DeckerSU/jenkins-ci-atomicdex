#!/usr/bin/env bash
# (c) Decker 2022

# based on azure-pipelines-release-stage-job.yml

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
Agent_OS=Linux
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

### Build MM2 Release
rm -f MM_VERSION
VERSION=2.1.${Build_BuildId}_${Build_SourceBranchName}_${COMMIT_HASH}_${Agent_OS}_Release
if ! grep -q $VERSION MM_VERSION; then
echo $VERSION > MM_VERSION
fi
cat MM_VERSION
touch mm2src/common/build.rs

if [ $AGENT_OS = "Linux" ]
then
# export UID=$(id -u) # read only variable
export GID=$(id -g)

docker build -f ${SCRIPTPATH}/Dockerfile.ubuntu.ci -t mm2_builder .

mkdir -p -v /home/$USER/.cargo/git
mkdir -p -v /home/$USER/.cargo/registry

# printenv > ${LOGFILE}
# docker run \
# -v /home/builder/.cargo/git:/root/.cargo/git \
# -v /home/builder/.cargo/registry:/root/.cargo/registry \
# -v $PWD:$PWD \
# -w $PWD \
# -e HOME=/root \
# -it mm2_builder

docker run \
    --user $UID:$GID \
    -v /home/$USER/.cargo/git:/root/.cargo/git \
    -v /home/$USER/.cargo/registry:/root/.cargo/registry \
    -v $PWD:$PWD \
    -w $PWD \
    -e HOME=/root \
    mm2_builder \
    /bin/bash -c "source /root/.cargo/env && cargo build --release -vv --target-dir target-xenial"
    # cargo rustc --lib --profile release --crate-type=staticlib --package mm2_bin_lib --target-dir target-xenial
else
    cargo build --release -vv
fi

### Prepare release build upload Linux
strip -g target-xenial/release/mm2

zip upload/mm2-${COMMIT_HASH}-${Agent_OS}-Release target-xenial/release/mm2 -j
# zip upload/mm2-${COMMIT_HASH}-${Agent_OS}-Release target-xenial/release/libmm2lib.a -j

log_print "Build end ..."