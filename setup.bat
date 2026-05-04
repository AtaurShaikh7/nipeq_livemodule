@echo off
echo ============================================================
echo  NipEQ - First Time Setup
echo ============================================================
echo.

REM Check Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed.
    echo.
    echo Please install Node.js LTS from: https://nodejs.org/
    echo After installing, re-run this script.
    echo.
    pause
    exit /b 1
)

echo [OK] Node.js found:
node --version

echo.
echo [1/2] Installing API dependencies...
cd /d D:\Ataur\Project_NipEQ\api
call npm install
if %errorlevel% neq 0 (
    echo [ERROR] API npm install failed.
    pause
    exit /b 1
)
echo [OK] API dependencies installed.

echo.
echo [2/2] Installing Frontend dependencies...
cd /d D:\Ataur\Project_NipEQ\frontend
call npm install
if %errorlevel% neq 0 (
    echo [ERROR] Frontend npm install failed.
    pause
    exit /b 1
)
echo [OK] Frontend dependencies installed.

echo.
echo ============================================================
echo  Setup complete!
echo  To start the application, run:  start.bat
echo ============================================================
pause
