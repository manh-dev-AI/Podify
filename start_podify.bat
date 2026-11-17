@echo off
cd /d "%~dp0"
title Podify - Khoi dong he thong

echo ========================================================
echo   PODIFY - Podcast ^& Audio Content Management System
echo ========================================================
echo.

if not exist "backend\venv\Scripts\python.exe" (
    echo [1/4] Chua co moi truong ao, dang tao backend\venv...
    python -m venv backend\venv
    if errorlevel 1 (
        echo [LOI] Khong tim thay Python. Vui long cai Python 3.10+ va thu lai.
        pause
        exit /b 1
    )
    echo [1/4] Dang cai dat thu vien tu backend\requirements.txt...
    backend\venv\Scripts\pip.exe install -r backend\requirements.txt
    if errorlevel 1 (
        echo [LOI] Cai dat thu vien that bai.
        pause
        exit /b 1
    )
) else (
    echo [1/4] Moi truong Python backend\venv da san sang.
)

if not exist ".env" (
    echo [2/4] Chua co file .env, dang tao tu .env.example...
    copy ".env.example" ".env" >nul
    echo.
    echo [LUU Y] Hay dien mat khau MySQL DB_PASSWORD vao file .env vua mo,
    echo         sau do luu file Ctrl+S va dong Notepad de tiep tuc!
    notepad ".env"
) else (
    echo [2/4] Da tim thay file cau hinh .env.
)

echo [3/4] Dang kiem tra ket noi MySQL va co so du lieu podify_db...
backend\venv\Scripts\python.exe -c "import sys; sys.path.insert(0,'backend'); from config import db; h=db.check_health(); sys.exit(0 if h.get('table_count',0)==12 else 2)"
if errorlevel 1 (
    echo       Dang khoi tao Schema, Triggers va du lieu mau...
    backend\venv\Scripts\python.exe backend\init_db.py
    if errorlevel 1 (
        echo.
        echo [LOI] Khong the ket noi MySQL. Hay kiem tra:
        echo       1. Dich vu MySQL80 dang chay trong Windows Services.
        echo       2. Thong tin DB_USER / DB_PASSWORD trong file .env da dung chua.
        pause
        exit /b 1
    )
) else (
    echo       Database podify_db [12 bang] da san sang.
)

echo [4/4] Dang khoi dong server tai http://127.0.0.1:5000 ...
echo       [Nhan Ctrl+C hoac dong cua so nay de tat server]
echo.
start "" cmd /c "timeout /t 2 /nobreak >nul & start http://127.0.0.1:5000"
backend\venv\Scripts\python.exe backend\app.py
pause
