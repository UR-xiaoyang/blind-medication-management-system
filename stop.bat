@echo off
chcp 65001 >nul
echo ========================================
echo   Blind Medication System - Stop All
echo ========================================
echo.

taskkill /f /im server.exe 2>nul && echo [OK] Backend stopped || echo [!] Backend not running
taskkill /f /im node.exe 2>nul && echo [OK] Frontend stopped || echo [!] Frontend not running

echo.
echo Done.
pause