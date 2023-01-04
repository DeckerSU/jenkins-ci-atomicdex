@echo off
rem (c) Decker, 2022 v0.01c
rem Requirements: Installed VS2022 with Desktop Developement with C++ enabled and Python 3.7.9 enabled.

set builddir=%cd%

pushd "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build" 
call "vcvarsall.bat" x64
popd

set PATH=%PATH%;%USERPROFILE%\.cargo\bin
rem rustup toolchain install stable-x86_64-pc-windows-msvc
rem rustup toolchain install nightly-msvc
rustup set default-host x86_64-pc-windows-msvc
rem https://stackoverflow.com/questions/58226545/how-to-switch-between-rust-toolchains
rustup override set nightly
rustc --version && cargo --version

rem set > %builddir%\target\release\env.txt
rem 2.1.7404_mm2.1_0f6c72615_Windows_NT_Release
rem 2.1.$(Build.BuildId)_$(Build.SourceBranchName)_$(COMMIT_HASH)_$(Agent.OS)_Release

IF NOT "%GIT_COMMIT%"=="" (
mkdir %builddir%\target\release
copy "%windir%\system32\msvcp140.dll" %builddir%\target\release & copy "%windir%\system32\vcruntime140.dll" %builddir%\target\release
set MANUAL_MM_VERSION=true
echo 2.1.%BUILD_ID%_%GIT_BRANCH:~7%_%GIT_COMMIT:~0,9%_%OS%_Release > %builddir%\MM_VERSION
type %builddir%\MM_VERSION
)

rem Emulate Failure
rem exit 1
cargo build --bin jenkins-hello-world --release
rem reg add "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /f /v KitsRoot10 /t REG_SZ /d "C:\Program Files\Windows Kits\10\"