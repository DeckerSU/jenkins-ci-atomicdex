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
AGENT_OS=Linux
BRANCH_NAME=${GIT_BRANCH:7} # cut off 'origin/' from the begin
COMMIT_HASH=${GIT_COMMIT:0:9}
###

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

cp ${SCRIPTPATH}/Dockerfile.ubuntu20.ci.sh .
# https://www.baeldung.com/ops/dockerfile-env-variable
docker build -f ${SCRIPTPATH}/Dockerfile.ubuntu20.ci -t dex_desktop_builder \
        --build-arg BUILDER_NAME=$USER \
        --build-arg BUILDER_UID=$(id -u) \
        --build-arg BUILDER_GID=$(id -g) .

# log_print Starting docker: -u $(id -u ${USER}):$(id -g ${USER})
docker run -u $(id -u ${USER}):$(id -g ${USER}) -v $PWD:$PWD -w $PWD -e HOME=/root dex_desktop_builder /bin/bash -c "./Dockerfile.ubuntu20.ci.sh"
zip upload/atomicdex-desktop-${BRANCH_NAME}-${COMMIT_HASH}-${AGENT_OS} ./ci_tools_atomic_dex/build-Release/atomicdex-desktop-linux-${COMMIT_HASH}-x86_64.AppImage -j    

