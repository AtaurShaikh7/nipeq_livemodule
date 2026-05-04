@echo off
REM Full run: effdate -> Outlook download -> file movement -> exe. All output to RunFinalMovement.log.
REM Test only (no exe): RunFinalMovement.bat test   OR   RunFinalMovementTest.bat

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RunFinalMovementWrapper.ps1" %*
if errorlevel 1 pause
