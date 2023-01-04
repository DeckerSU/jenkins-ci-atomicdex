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

###
AGENT_OS=osx
BRANCH_NAME=${GIT_BRANCH:7} # cut off 'origin/' from the begin
COMMIT_HASH=${GIT_COMMIT:0:9}
###

### Recreate upload dir
rm -rf ${WORKSPACE}/upload
mkdir ${WORKSPACE}/upload

### Set environment variables (~/.zshrc seems doesn't launch, as session is non-interactive?)
export PATH="/usr/local/opt/openjdk@11/bin:/Users/builder/Library/Python/3.9/bin:/usr/local/bin:$PATH"
# /Applications/Xcode.app/Contents/Developer/usr/bin - don't need this bcz we launch altool via xcrun
export QT_INSTALL_CMAKE_PATH=/Users/$USER/Qt/5.15.2/clang_64/lib/cmake
export QT_ROOT=/Users/$USER/Qt/5.15.2
export MACOSX_DEPLOYMENT_TARGET=10.15
export CC=clang
export CXX=clang++
export CXXFLAGS="-DBOOST_ASIO_DISABLE_STD_ALIGNED_ALLOC ${CXXFLAGS}"

# security find-identity -p codesigning # # 4230B72331B9D6856F200D19AA1891FBFB9B2059
export MAC_SIGN_IDENTITY="0914ACE36B36525F96384E3B61A853B3B5339C2C"
export INSTALLER_MAC_SIGN_IDENTITY="0914ACE36B36525F96384E3B61A853B3B5339C2C"

# https://stackoverflow.com/questions/43216273/object-file-was-built-for-newer-osx-version-than-being-linked
# log_print "MACOSX_DEPLOYMENT_TARGET: $MACOSX_DEPLOYMENT_TARGET"
log_print "MAC_SIGN_IDENTITY: $MAC_SIGN_IDENTITY"

### Unlock keychain login.keychain for signing
security unlock-keychain -p ${SIGNING_PASSWORD} login.keychain

# we are in workspace, i.e. in git repo directory
git submodule init
git submodule sync --recursive
git submodule update --init --recursive

if [ ! -d "libwally-core" ]; then
git clone https://github.com/KomodoPlatform/libwally-core.git
fi
pushd libwally-core
git checkout .
git apply -v ${SCRIPTPATH}/build-osx-patch.diff
./tools/autogen.sh
PYTHON_VERSION=3 ./configure --disable-shared
#make -j3 
make -j$(sysctl -n hw.logicalcpu)
sudo make install
popd

pushd ci_tools_atomic_dex
nimble build -y
./ci_tools_atomic_dex bundle Release --osx_sdk=$HOME/sdk/MacOSX10.15.sdk --compiler=clang++
popd
