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

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

### Build MM2 WASM target
rm -f MM_VERSION
echo $SHORT_HASH > MM_VERSION

if [ $AGENT_OS = "Linux" ]
then

docker build -f ${SCRIPTPATH}/Dockerfile.wasm.ci -t mm2_wasm_builder .

mkdir -p -v /home/$USER/.cargo/git
mkdir -p -v /home/$USER/.cargo/registry

# printenv > ${LOGFILE}

docker run \
    --user $UID:$GID \
    -v /home/$USER/.cargo/git:/root/.cargo/git \
    -v /home/$USER/.cargo/registry:/root/.cargo/registry \
    -v $PWD:$PWD \
    -w $PWD \
    -e HOME=/root \
    mm2_wasm_builder \
    /bin/bash -c "source /root/.cargo/env && wasm-pack build --release mm2src/mm2_bin_lib --target web --out-dir ../../target/target-wasm-release"

(cd ./target/target-wasm-release && zip -r - .) > ${WORKSPACE}/upload/mm2_${SHORT_HASH}-wasm.zip

else
    log_print "Nothing to do, agent OS is not Linux!"
fi


log_print "Build end ..."