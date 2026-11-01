@echo off
title JLSP Web Admin Dashboard (Vite)
cd /d "%~dp0"

echo ================================================================
echo       DANG KHOI CHAY JLSP WEB ADMIN DASHBOARD
echo ================================================================

if not exist node_modules (
    echo Dang cai dat cac thu vien (npm install)...
    call npm install
)

echo Khoi dong Vite dev server...
call npm run dev

pause
