@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ==========================================
echo   盲人智能用药管理系统 - 完整启动脚本
echo ==========================================
echo.

:: 检查 MySQL
echo [1/5] 检查 MySQL...
mysql --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 未检测到 MySQL，请先安装 MySQL
    pause
    exit /b 1
)
echo ✅ MySQL 已安装

:: 检查 Go
echo [2/5] 检查 Go...
go version >nul 2>&1
if errorlevel 1 (
    echo ❌ 未检测到 Go，请先安装 Go
    pause
    exit /b 1
)
echo ✅ Go 已安装

:: 检查 Node.js
echo [3/5] 检查 Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 未检测到 Node.js，请先安装 Node.js
    pause
    exit /b 1
)
echo ✅ Node.js 已安装

:: SQLite is initialized automatically by the Go service; no MySQL password is stored here.
echo [4/5] 使用 SQLite 自动初始化数据库...
echo ✅ 数据库将在服务启动时创建

:: 启动后端
echo [5/5] 启动服务...
echo.
echo ▶ 启动 Go 后端 (端口 8080)...
start "Backend" cmd /c "cd /d "%~dp0" && go run cmd/server/main.go"

:: 等待后端启动
timeout /t 3 /nobreak >nul

:: 启动前端
echo ▶ 启动 Vue 前端 (端口 3000)...
start "Frontend" cmd /c "cd /d "%~dp0\..\blind-medication-frontend" && npm run dev"

:: 管理员初始化请在安全终端中手动执行，不在脚本中保存密码。
echo [提示] 请设置 JWT_SECRET 后启动，并手动调用 /api/init-admin 初始化管理员。

echo.
echo ==========================================
echo   系统已启动！
echo.
echo   前端地址: http://localhost:3000
echo   后端地址: http://localhost:8080
echo.
echo   管理员账号: 请在初始化时自行指定
echo   管理员密码: 不在脚本中保存
echo ==========================================
echo.
pause
