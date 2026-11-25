@echo off
cd /d "%~dp0"
title Podify - Chay bo kiem thu

echo ========================================================
echo   PODIFY - Chay kiem thu toan he thong (20 Test Cases)
echo ========================================================
echo.

if not exist "backend\venv\Scripts\python.exe" (
    echo [LOI] Chua co backend\venv. Hay chay start_podify.bat truoc!
    pause
    exit /b 1
)

set TEST_MYSQL=1
backend\venv\Scripts\python.exe -m unittest discover -s tests -p "test_*.py" -v
echo.
pause
