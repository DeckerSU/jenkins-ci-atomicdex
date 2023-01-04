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
Agent_OS=Linux
AGENT_OS=${Agent_OS}
Build_BuildId=${BUILD_ID}
Build_SourceBranchName=${GIT_BRANCH:7} # cut off 'origin/' from the begin
COMMIT_HASH=${GIT_COMMIT:0:9}
###

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

### Build

# export UID=$(id -u) # read only variable
export GID=$(id -g)

docker build -f ${SCRIPTPATH}/Dockerfile.ubuntu.ci -t mm2_builder .

mkdir -p -v /home/$USER/.cargo/git
mkdir -p -v /home/$USER/.cargo/registry

docker run \
    --user $UID:$GID \
    -v /home/$USER/.cargo/git:/root/.cargo/git \
    -v /home/$USER/.cargo/registry:/root/.cargo/registry \
    -v $PWD:$PWD \
    -w $PWD \
    -e HOME=/root \
    mm2_builder \
    /bin/bash -c "source /root/.cargo/env && cargo build --release -vv --target-dir target-xenial"

### Prepare release build upload Linux
objcopy --only-keep-debug target-xenial/release/jenkins-hello-world target-xenial/release/jenkins-hello-world.debug
strip -g target-xenial/release/jenkins-hello-world

zip upload/hello-world-${COMMIT_HASH}-${Agent_OS}-Release target-xenial/release/jenkins-hello-world -j

log_print "Build end ..."