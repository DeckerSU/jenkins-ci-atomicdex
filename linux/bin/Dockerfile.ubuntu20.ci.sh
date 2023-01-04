#!/usr/bin/env bash
# (c) Decker 2022

# should be used to build and bundle (via linuxdeployqt) app inside
# a docker environment 

git config --global --add safe.directory '*'
git submodule init
git submodule sync --recursive
git submodule update --init --recursive
# git pull --recurse-submodules

old_build_flow () {
    git clone https://github.com/KomodoPlatform/libwally-core.git
    pushd libwally-core
    ./tools/autogen.sh
    PYTHON_VERSION=3.9 ./configure --disable-shared
    sudo make -j$(nproc --all) install
    popd

    pushd ci_tools_atomic_dex/vcpkg-repo
    ./bootstrap-vcpkg.sh -disableMetrics
    popd

    # apt-get install -y libpulse-dev libssl-dev libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb1-dev libxcb-keysyms1-dev libxcb-render-util0-dev libxcb-xinerama0 libgstreamer-plugins-base1.0-dev
    # apt-get install -y libasound2 libxtst6 libxi6 libxcursor1 libxrandr2 libxdamage1 libxcomposite-dev libnspr4 libnss3 # libQt5WebEngineCore.so.5.15.2

    mkdir -p build
    pushd build
    cmake -DCMAKE_BUILD_TYPE=Release ../
    # https://stackoverflow.com/questions/36633074/set-the-number-of-threads-in-a-cmake-build
    cmake --build . --config Release --target atomicdex-desktop -- -j $(nproc --all)
    popd
}

old_install_deps () {
    # Install deps (Linux)
    # sudo ./ci_tools_atomic_dex/ci_scripts/linux_script.sh
    # base deps

    sudo apt-get install build-essential \
                    libgl1-mesa-dev \
                    ninja-build \
                    curl \
                    wget \
                    zstd \
                    software-properties-common \
                    lsb-release \
                    libpulse-dev \
                    libtool \
                    autoconf \
                    unzip \
                    libssl-dev \
                    libxkbcommon-x11-0 \
                    libxcb-icccm4 \
                    libxcb-image0 \
                    libxcb1-dev \
                    libxcb-keysyms1-dev \
                    libxcb-render-util0-dev \
                    libxcb-xinerama0 \
                    libgstreamer-plugins-base1.0-dev \
                    git -y

    # for link atomicdex-desktop binary
    sudo apt-get install -y libasound2 libxtst6 libxi6 libxcursor1 libxrandr2 libxdamage1 libxcomposite-dev libnspr4 libnss3 # libQt5WebEngineCore.so.5.15.2
    # for making app bundle
    sudo apt-get install -y libxcb-shape0 libcups2 libgtk-3-0
    # for launch linuxdeployqt
    sudo apt-get install -y libfuse2
}

# apply environment variables, using .bashrc unsuitable here, bcz session is non-interactive
source ~/.env_bashrc

# important to have write access, because during vcpkg prepare/build and nimble build
# several directories created there
sudo chmod -R 777 /root/.cache
sudo chmod -R 777 /root/.nimble

# get libwally
git clone https://github.com/KomodoPlatform/libwally-core.git
pushd libwally-core
./tools/autogen.sh
PYTHON_VERSION=3.9 ./configure --disable-shared
make -j$(nproc --all)
sudo make install
sudo rm src/secp256k1/src/.deps/.dirstamp
popd


# vcpkg deps (All)
pushd ci_tools_atomic_dex/vcpkg-repo
./bootstrap-vcpkg.sh -disableMetrics
popd

# Build AtomicDEX (Linux)
cd ci_tools_atomic_dex
nimble build -y
./ci_tools_atomic_dex build Release
APPIMAGE_EXTRACT_AND_RUN=1 ./ci_tools_atomic_dex bundle Release

# ci_tools_atomic_dex/linux_misc/linuxdeployqt-7-x86_64.AppImage :
# https://github.com/AppImage/AppImageKit/wiki/FUSE
# https://github.com/probonopd/linuxdeployqt/issues/340
# For launch under docker we need APPIMAGE_EXTRACT_AND_RUN=1 env. variable present.