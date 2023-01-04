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
   echo -e [$datetime] $1 | tee -a $LOGFILE
   
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
# log_print "SIGNING_PASSWORD: ${SIGNING_PASSWORD}"

###
Agent_OS=Darwin
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

### Set environment variables
export PATH="$HOME/.cargo/bin:/usr/local/bin:$PATH"

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

cargo build --release -vv
strip -S target/release/jenkins-hello-world # -S Remove the debugging symbol table entries

### Signing app
log_print "Signing app ... "
export MAC_SIGN_IDENTITY="0914ACE36B36525F96384E3B61A853B3B5339C2C"
security unlock-keychain -p ${SIGNING_PASSWORD} login.keychain
codesign --remove-signature target/release/jenkins-hello-world || true
codesign --keychain login.keychain -s "${MAC_SIGN_IDENTITY}" --timestamp --options runtime target/release/jenkins-hello-world
codesign -vv -d target/release/jenkins-hello-world

zip upload/mm2-${COMMIT_HASH}-${Agent_OS}-Release target/release/jenkins-hello-world -j 

log_print "Build end ..."