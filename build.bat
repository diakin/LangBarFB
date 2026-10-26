@echo off
rem Build LangBarFB.
rem   build.bat 32   - bin\langbar32.exe with rqlcl32.dll next to it
rem   build.bat 64   - bin\langbar64.exe with rqlcl64.dll
rem
rem Paths are read from build_local.bat if it exists (not in git, copy
rem build_local.bat.example and edit it):
rem   FB32DIR - folder of the 32-bit FreeBASIC (fbc.exe or fbc32.exe)
rem   FB64DIR - folder of the 64-bit FreeBASIC (fbc.exe or fbc64.exe)
rem   RQLCL   - RqLcl folder of the unIDE repository, branch mainTest
rem             (default ..\unIDE\RqLcl)
rem Without FB32DIR / FB64DIR the compiler is looked up in PATH.

setlocal
if exist "%~dp0build_local.bat" call "%~dp0build_local.bat"
if "%RQLCL%"=="" set RQLCL=..\unIDE\RqLcl

if "%1"=="32" goto win32
if "%1"=="64" goto win64
echo Usage: build.bat 32 or build.bat 64
exit /b 1

:win32
set BITS=32
set FBDIR=%FB32DIR%
goto findfbc

:win64
set BITS=64
set FBDIR=%FB64DIR%

:findfbc
set FBC=
if "%FBDIR%"=="" goto frompath
if exist "%FBDIR%\fbc%BITS%.exe" set FBC=%FBDIR%\fbc%BITS%.exe
if "%FBC%"=="" if exist "%FBDIR%\fbc.exe" set FBC=%FBDIR%\fbc.exe
if "%FBC%"=="" goto nofbc
goto build

:frompath
set FBC=fbc%BITS%.exe
where /q %FBC%
if errorlevel 1 set FBC=fbc.exe
where /q %FBC%
if errorlevel 1 goto nofbc

:build
if not exist "%RQLCL%\inc\rqlcl.bi" goto norqlcl
if not exist bin mkdir bin
echo Compiler: %FBC%
rem fbc runs from src: langbar.rc refers to langbar.ico relative to it
for %%I in ("%RQLCL%") do set RQLCL=%%~fI
pushd src
"%FBC%" -s gui langbar.bas langbar.rc -i "%RQLCL%\inc" -x ..\bin\langbar%BITS%.exe
set FBERR=%errorlevel%
popd
if not "%FBERR%"=="0" exit /b 1
copy /y "%RQLCL%\bin\rqlcl%BITS%.dll" bin\ >nul
echo Done: bin\langbar%BITS%.exe
exit /b 0

:nofbc
echo FreeBASIC %BITS%-bit compiler not found. Set FB%BITS%DIR in build_local.bat
exit /b 1

:norqlcl
echo RqLcl not found: %RQLCL%\inc\rqlcl.bi. Set RQLCL in build_local.bat
exit /b 1
