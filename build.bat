@echo off
rem Build LangBarFB (32-bit only): bin\langbar32.exe with rqlcl32.dll next to it.
rem
rem Paths are read from build_local.bat if it exists (not in git, copy
rem build_local.bat.example and edit it):
rem   FB32DIR - folder of the 32-bit FreeBASIC (fbc.exe or fbc32.exe)
rem   RQLCL   - RqLcl folder of the unIDE repository, branch mainTest
rem             (default ..\unIDE\RqLcl)
rem Without FB32DIR the compiler is looked up in PATH.

setlocal
if exist "%~dp0build_local.bat" call "%~dp0build_local.bat"
if "%RQLCL%"=="" set RQLCL=..\unIDE\RqLcl

set FBC=
if "%FB32DIR%"=="" goto frompath
if exist "%FB32DIR%\fbc32.exe" set FBC=%FB32DIR%\fbc32.exe
if "%FBC%"=="" if exist "%FB32DIR%\fbc.exe" set FBC=%FB32DIR%\fbc.exe
if "%FBC%"=="" goto nofbc
goto build

:frompath
set FBC=fbc32.exe
where /q %FBC%
if errorlevel 1 set FBC=fbc.exe
where /q %FBC%
if errorlevel 1 goto nofbc

:build
if not exist "%RQLCL%\inc\rqlcl.bi" goto norqlcl
if not exist bin mkdir bin
echo Compiler: %FBC%
rem fbc runs from src: langbar32.rc refers to RysLat2.ico relative to it
for %%I in ("%RQLCL%") do set RQLCL=%%~fI
pushd src
"%FBC%" -s gui langbar32.bas langbar32.rc -i "%RQLCL%\inc" -x ..\bin\langbar32.exe
set FBERR=%errorlevel%
popd
if not "%FBERR%"=="0" exit /b 1
copy /y "%RQLCL%\bin\rqlcl32.dll" bin\ >nul
echo Done: bin\langbar32.exe
exit /b 0

:nofbc
echo FreeBASIC 32-bit compiler not found. Set FB32DIR in build_local.bat
exit /b 1

:norqlcl
echo RqLcl not found: %RQLCL%\inc\rqlcl.bi. Set RQLCL in build_local.bat
exit /b 1
