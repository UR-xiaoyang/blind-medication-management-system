@echo off
chcp 65001 >nul
echo ==========================================
echo   盲人智能用药管理系统 - 启动脚本
echo ==========================================
echo.

echo [1/3] 后端使用 SQLite 自动初始化，无需 MySQL 密码

echo.

echo [2/3] 启动 Go 后端...
start "Backend" cmd /c "go run cmd/server/main.go"
echo ✅ 后端启动中 (http://localhost:8080)
echo.

echo [3/3] 启动 Vue 前端...
cd /d "%~dp0\..\blind-medication-frontend"
start "Frontend" cmd /c "npm run dev"
echo ✅ 前端启动中 (http://localhost:3000)
echo.

echo ==========================================
echo   系统已启动！
echo   前端: http://localhost:3000
echo   后端: http://localhost:8080
echo ==========================================
echo.
echo 首次使用前请先设置 JWT_SECRET，然后在安全终端中调用 /api/init-admin 创建管理员。
echo 管理员密码不得写入脚本、命令历史或版本库。
echo.
pause
