#!/usr/bin/env bash
set -e

echo "=========================================="
echo "  盲人智能用药管理系统 - 完整启动脚本"
echo "=========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 检查依赖
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ 未检测到 $1，请先安装"
    exit 1
  fi
  echo "✅ $1 已安装"
}

check_cmd mysql
check_cmd go
check_cmd node

# 初始化数据库
echo
echo "[*] 初始化数据库..."
mysql -u root -p < "$SCRIPT_DIR/config/init.sql" 2>/dev/null || echo "⚠️  数据库可能已存在，继续..."

# 后端配置要求：设置 JWT_SECRET；管理员初始化请使用交互式/外部安全流程
export JWT_SECRET="${JWT_SECRET:?请先设置 JWT_SECRET}"
export MEDBOX_ADMIN_PASSWORD="${MEDBOX_ADMIN_PASSWORD:?请先设置 MEDBOX_ADMIN_PASSWORD}"

# 启动后端
echo
echo "[*] 启动 Go 后端 (端口 8080)..."
cd "$SCRIPT_DIR"
go run cmd/server/main.go &
BACKEND_PID=$!

sleep 3

# 启动前端
echo "[*] 启动 Vue 前端 (端口 3000)..."
cd "$SCRIPT_DIR/../blind-medication-frontend"
npm run dev &
FRONTEND_PID=$!

sleep 5

# 管理员初始化由安全环境变量提供密码；不会在脚本中保存默认密码
curl -s -X POST http://localhost:8080/api/init-admin \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${MEDBOX_ADMIN_USERNAME:-admin}\",\"password\":\"${MEDBOX_ADMIN_PASSWORD}\"}" || echo "⚠️  管理员可能已存在"

echo
echo "=========================================="
echo "  系统已启动！"
echo
echo "  前端地址: http://localhost:3000"
echo "  后端地址: http://localhost:8080"
echo
echo "  管理员账号: ${MEDBOX_ADMIN_USERNAME:-admin}"
echo "  管理员密码: 已通过环境变量提供（不显示）"
echo "=========================================="

# 等待子进程
wait $BACKEND_PID $FRONTEND_PID
