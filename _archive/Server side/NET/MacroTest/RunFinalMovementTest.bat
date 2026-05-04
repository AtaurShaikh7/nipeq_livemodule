@echo off
REM Test run: effdate only (no file movement, no exe).

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RunFinalMovementWrapper.ps1" -DownloadOnly
echo.
echo Full log: %~dp0RunFinalMovement.log
echo.
pause
