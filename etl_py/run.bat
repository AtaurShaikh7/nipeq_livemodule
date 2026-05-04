@echo off
title ETL Pipeline
cd /d "%~dp0"
python -u main.py %*
set EXIT_CODE=%errorlevel%
echo.
echo =========================================
echo  ETL finished with exit code: %EXIT_CODE%
echo =========================================
echo  Press any key to close this window...
pause >nul
exit /b %EXIT_CODE%
