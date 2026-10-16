@echo off
chcp 65001 >nul
echo ========================================
echo   Blind Medication System - Launcher
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

if not exist "blind-medication-frontend" (
    echo [ERROR] Frontend folder not found
    pause
    goto end
)

if not exist "blind-medication-backend" (
    echo [ERROR] Backend folder not found
    pause
    goto end
)

echo.
echo [1/3] Starting Backend with SQLite database...
start "Backend" cmd /k "cd /d "%SCRIPT_DIR%blind-medication-backend" && server.exe & pause"

echo.
echo [2/3] Starting Frontend...
start "Frontend" cmd /c "cd /d "%SCRIPT_DIR%blind-medication-frontend" && npm run dev"

echo.
echo ========================================
echo   Started! Check the popup windows.
echo ----------------------------------------
echo   Backend API:   http://localhost:8080
echo   Frontend:      http://localhost:3000
echo ========================================
echo.

:end
pause