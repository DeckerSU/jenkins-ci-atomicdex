@echo off
rem (c) Decker, 2022 v0.01a

rem assuming we are already in Git cloned repo directory
set builddir=%cd%

pushd "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build" 
call "vcvarsall.bat" x64
popd

set PATH=%PATH%;%USERPROFILE%\.cargo\bin
rem rustup toolchain install stable-x86_64-pc-windows-msvc
rem rustup toolchain install nightly-msvc
rustup set default-host x86_64-pc-windows-msvc
rem https://stackoverflow.com/questions/58226545/how-to-switch-between-rust-toolchains
rem rustup override set nightly 
rem rustup override set nightly-2023-06-01
rustup install nightly-2023-06-01
rustc --version && cargo --version

rem update cc and cmake crates to know about VS2022
cargo update -p cc
cargo update -p cmake
cargo update -p prost-build

rem https://github.com/dotnet/msbuild/issues/4230
rem https://developercommunity.visualstudio.com/t/ucrt-doesnt-work-in-x64-msbuild/1184283

rem reg delete "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /f /v KitsRoot10

rem avoid colliding filename mm2.pdb for mm2 bin and lib (!)
rem copy "%~dp0mm2-lib-name.diff" "%builddir%"
rem git apply -v mm2-lib-name.diff
rem instead of patching colliding names we build only bin (no library) for now

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

cargo build --bin mm2 --release
rem reg add "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /f /v KitsRoot10 /t REG_SZ /d "C:\Program Files\Windows Kits\10\"
mkdir %builddir%\upload
pushd target\release && 7z a -tzip %builddir%\upload\mm2-%GIT_COMMIT:~0,9%-Win64.zip mm2.exe msvcp140.dll vcruntime140.dll && popd
