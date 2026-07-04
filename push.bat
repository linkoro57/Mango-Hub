@echo off
setlocal

cd /d "%~dp0"

for /f "delims=" %%i in ('git branch --show-current 2^>nul') do set "BRANCH=%%i"
if not defined BRANCH (
    echo Failed to detect the current Git branch.
    pause
    exit /b 1
)

git status --short
echo.

set /p "COMMIT_MSG=Commit message: "
if not defined COMMIT_MSG (
    echo Commit message is required.
    pause
    exit /b 1
)

git add -A
if errorlevel 1 (
    echo git add failed.
    pause
    exit /b 1
)

git commit -m "%COMMIT_MSG%"
if errorlevel 1 (
    echo git commit failed.
    pause
    exit /b 1
)

git push origin %BRANCH%
if errorlevel 1 (
    echo git push failed.
    pause
    exit /b 1
)

echo.
echo Push completed on branch %BRANCH%.
pause
