@echo off
rem Build LangBarFB.
rem   build.bat 32   - bin\langbar32.exe with rqlcl32.dll next to it
rem   build.bat 64   - bin\langbar64.exe with rqlcl64.dll
rem FBC   - path to the compiler (default fbc32.exe / fbc64.exe from PATH)
rem RQLCL - RqLcl folder of the unIDE repository, branch mainTest
rem         (default ..\unIDE\RqLcl)

if "%RQLCL%"=="" set RQLCL=..\unIDE\RqLcl

if "%1"=="32" goto win32
if "%1"=="64" goto win64
echo Usage: build.bat 32 or build.bat 64
exit /b 1

:win32
if "%FBC%"=="" set FBC=fbc32.exe
set BITS=32
goto build

:win64
if "%FBC%"=="" set FBC=fbc64.exe
set BITS=64

:build
if not exist bin mkdir bin
"%FBC%" -s gui src\langbar.bas -i "%RQLCL%\inc" -x bin\langbar%BITS%.exe
if errorlevel 1 exit /b 1
copy /y "%RQLCL%\bin\rqlcl%BITS%.dll" bin\ >nul
echo Done: bin\langbar%BITS%.exe
