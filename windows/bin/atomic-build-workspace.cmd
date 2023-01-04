@echo off
rem (c) Decker, 2022 v0.01c
rem Requirements: Installed VS2022 with Desktop Developement with C++ enabled and Python 3.7.9 enabled.

set builddir=%cd%

rem you can start from the beginning or choose step via goto
rem goto build_libwally
goto install_sources

:install_qt
rem set PATH=%PATH%;"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\VC\SecurityIssueAnalysis\python"
set PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64;%PATH%
python --version
python.exe -m pip install --upgrade pip
python.exe -m pip install aqtinstall
python.exe -m aqt install-qt windows desktop "5.15.2" win64_msvc2019_64 -O "C:\Qt" -m qtcharts debug_info qtwebengine  -b https://qt-mirror.dannhauer.de/
:install_scoop
powershell Set-ExecutionPolicy RemoteSigned -scope CurrentUser
rem https://superuser.com/questions/1183705/install-net-framework-4-or-4-6-in-windows-server-2016
rem https://learn.microsoft.com/en-us/security/engineering/solving-tls1-problem
rem reg add HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319 /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f /reg:64
rem Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
rem powershell iex ((new-object net.webclient).DownloadString('https://get.scoop.sh'))
powershell [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; irm get.scoop.sh -outfile 'install.ps1'
powershell .\install.ps1 -RunAsAdmin
:install_packages
set PATH=%PATH%;%USERPROFILE%\scoop\apps\scoop\current\bin
powershell scoop install llvm --global
powershell scoop install ninja --global
powershell scoop install cmake --global
powershell scoop install git --global
powershell scoop install 7zip  --global

:install_sources
set PATH=%PATH%;%ProgramData%\scoop\apps\llvm\current\bin;%ProgramData%\scoop\apps\cmake\current\bin;%ProgramData%\scoop\apps\git\current\bin;%ProgramData%\scoop\apps\ninja\current;%ProgramData%\scoop\apps\7zip\current;
rem if not exist AtomicDEX-Desktop 
git clone -b v0.8.5 --recurse-submodules https://github.com/KomodoPlatform/libwally-core.git
rem git clone --recurse-submodules https://github.com/KomodoPlatform/AtomicDEX-Desktop.git

:build_libwally
pushd "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build" 
call "vcvarsall.bat" x64
popd
pushd "%builddir%\libwally-core"
powershell "(Get-Content -Raw .\tools\msvc\build.bat) -replace 'src\/psbt.c','src/psbt.c src/pullpush.c' | Set-Content -Path .\tools\msvc\build-new.bat"
call .\tools\msvc\build-new.bat
popd
copy "%builddir%\libwally-core\wally.dll" "%builddir%\wally\wally.dll" /y

:prepare_vcpkg
pushd "%builddir%\ci_tools_atomic_dex\vcpkg-repo"
git submodule init
git submodule sync --recursive
git submodule update --init --recursive
call .\bootstrap-vcpkg.bat
popd

:build
pushd "%builddir%"
set PATH=%PATH%;%ProgramData%\scoop\apps\llvm\current\bin;%ProgramData%\scoop\apps\cmake\current\bin;%ProgramData%\scoop\apps\git\current\bin;%ProgramData%\scoop\apps\ninja\current;%ProgramData%\scoop\apps\7zip\current;
mkdir build 2>nul
cd build
set QT_INSTALL_CMAKE_PATH=C:\Qt\5.15.2\msvc2019_64
set QT_ROOT=C:\Qt
cmake -DCMAKE_BUILD_TYPE=Release ../ -GNinja -DCMAKE_PREFIX_PATH=C:\Qt\5.15.2\msvc2019_64\lib\cmake\Qt5
cmake --build . --config Release --target atomicdex-desktop
popd
