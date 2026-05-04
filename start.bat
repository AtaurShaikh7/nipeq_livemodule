@echo off
echo ============================================================
echo  NipEQ - Starting Application
echo ============================================================
echo.
echo Starting API server...
start "NipEQ API" cmd /k "cd /d D:\Ataur\Project_NipEQ\api && npx ts-node -r tsconfig-paths/register src/index.ts"

echo Waiting 4 seconds for API to start...
timeout /t 4 /nobreak >nul

echo Starting Angular frontend...
start "NipEQ Frontend" cmd /k "cd /d D:\Ataur\Project_NipEQ\frontend && npx ng serve --open"

echo.
echo ============================================================
echo  API   : http://localhost:3000
echo  App   : http://localhost:4200  (opens in browser)
echo.
echo  Login : support@valuefy.com  /  NipEQ@2025
echo ============================================================
