@echo off
cd /d "%~dp0"
title Podify - Reset Database

echo ========================================================
echo   PODIFY - Khoi tao / Reset MySQL Database (12 bang)
echo ========================================================
echo.

if not exist "backend\venv\Scripts\python.exe" (
    echo [LOI] Chua co backend\venv. Hay chay start_podify.bat truoc!
    pause
    exit /b 1
)

if not exist ".env" (
    echo [LOI] Chua co file .env. Hay copy .env.example thanh .env va dien DB_PASSWORD!
    pause
    exit /b 1
)

backend\venv\Scripts\python.exe backend\init_db.py
echo.
if errorlevel 1 (
    echo [THAT BAI] Kiem tra lai cau hinh MySQL trong file .env.
) else (
    echo [THANH CONG] Da tao lai 12 bang va du lieu mau!
)
pause
