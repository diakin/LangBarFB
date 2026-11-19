@echo off
rem Save userdata\user_dict.dic and userdata\rules.ini to GitHub:
rem commit to the current branch and push. Needs git in PATH.
setlocal
pushd "%~dp0"
git add userdata
git diff --cached --quiet -- userdata
if not errorlevel 1 (
  echo userdata: no changes
  popd
  exit /b 0
)
git commit -m "userdata: user words and switching rules" -- userdata
if errorlevel 1 goto failed
git pull --no-rebase --no-edit
if errorlevel 1 goto failed
git push
if errorlevel 1 goto failed
echo userdata saved
popd
exit /b 0
:failed
echo userdata: git error, see above
popd
exit /b 1
