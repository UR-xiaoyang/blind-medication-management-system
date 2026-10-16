# 盲人智能用药管理系统

面向视障患者的智能用药辅助系统：ESP32 智能药盒负责执行与传感，Go 服务端提供业务、设备与实时消息能力，Vue 管理后台用于照护管理，Flutter 志愿者端处理告警响应；仓库同时保存可打印的 OpenSCAD 结构件。

## 先读什么

1. [项目状态与启动指南](docs/PROJECT_STATE.md)：当前可验证范围、边界、目录和排障入口。
2. [后端路由](blind-medication-backend/internal/handler/router.go)：HTTP API 的唯一代码级入口。
3. [硬件接线](firmware/esp32_wroom32_medication/WIRING.md)：接线与供电安全约束。
4. [志愿者端待办](volunteer_app/TODO.md)：移动端尚未完成的功能。

## 当前验证状态

本次已在本机完成以下静态/构建验证：

| 范围 | 结果 |
| --- | --- |
| Go 后端 | `go test ./...` 通过（目前各包没有测试文件） |
| Vue 管理后台 | `npm run build` 通过；产物存在体积告警 |
| ESP32-WROOM-32 固件 | `arduino-cli compile --fqbn esp32:esp32:esp32 .` 通过；Flash 占用 88%，RAM 占用 15% |
| Flutter 志愿者端 | 本机未安装 `flutter`，尚未执行依赖解析、静态分析或构建 |
| Docker | 本机未安装 Docker，尚未执行 Compose 启动验证 |

注意：构建通过不等于硬件已接线、MQTT 已连通或端到端出药流程已验证。

## 本地启动

### 后端

```bash
cd blind-medication-backend
go run cmd/server/main.go
```

服务监听 `:8080`，SQLite 数据库默认创建在 `blind-medication-backend/data/blind_medication.db`。首次使用时初始化管理员：

```bash
curl -X POST http://localhost:8080/api/init-admin \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"请设置强密码"}'
```

### 管理后台

```bash
cd blind-medication-frontend
npm install
npm run dev
```

开发服务器默认使用 `:3000`，并代理 `/api` 至后端 `:8080`。

### 浏览器设备模拟器

不接硬件时，可通过管理后台中的模拟器与 `/api/ws` WebSocket、`/api/simulator/*` 接口验证基础设备消息流程。模拟器设备 ID 必须与后台中的设备记录一致。

## Docker 部署

### 本地 Compose

```bash
docker compose -f docker-compose.local.yml up --build -d
```

暴露端口：前端 `3000`、后端 `8080`。

### 生产 Compose

```bash
cp .env.example .env
# 填写 APP_DOMAIN 与强随机 JWT_SECRET
docker compose up --build -d
```

生产 Compose 使用 Nginx，默认仅绑定 `127.0.0.1:${APP_PORT:-18080}`；如需公网 HTTPS，应在外部反向代理或负载均衡层终止 TLS。根目录 `Caddyfile` 是另一份可选的 Caddy 配置，不是当前 `docker-compose.yml` 所引用的部署配置。

## 目录

```text
blind-medication-backend/     Go + Gin + GORM/SQLite + MQTT + WebSocket
blind-medication-frontend/    Vue 3 + Vite + Pinia + Element Plus 管理后台
firmware/                     ESP32-WROOM-32 Arduino 固件与接线说明
volunteer_app/                Flutter + Riverpod 志愿者告警应用
lab/                          独立 Python 仿真脚本
*.scad / *.stl                药盒、推药机构与齿带相关的 3D 打印文件
docs/                         项目状态与后续维护入口
```

## 重要边界

- 新功能统一使用“剂次包”（`DosePackage`）；`/api/schedules` 仅为旧接口兼容层。
- MQTT 是真实设备的通信路径，但服务在 MQTT 不可用时仍可运行；浏览器模拟器可走 WebSocket 通道。
- ESP32-WROOM-32 的 GPIO6–11 为片上 Flash 引脚，严禁接外设；四路舵机使用独立 5V/2A+ 电源并与 ESP32 共地。
- 固件已接近 Flash 容量上限（88%），新增库或资源前必须重新编译确认余量。

## 安全与公开仓库检查

- `.env`、SQLite 数据库、日志、依赖目录和本地构建产物已加入 `.gitignore`；公开前仍必须检查 `git diff --cached`。
- 生产环境必须设置强随机 `JWT_SECRET`、唯一设备令牌和唯一 AP 密码；固件不会编译进站点 WiFi、后台地址或设备令牌。
- 若历史版本中的凭据曾真实使用过，应立即轮换；仅从当前文件删除不足以撤销已泄露凭据。
- 本项目涉及药品和执行机构，部署前必须完成机械限位、断电、空载、重复出药和人工应急流程测试。

## 许可证

代码、硬件设计文件和文档按仓库根目录 `LICENSE` 中的 MIT License 发布。发布前仍需确认其中包含的第三方依赖、字体、音频和其他素材各自遵循其上游许可证；本许可证不替代这些第三方许可。

详细状态、已知文档冲突、构建命令和建议的整理顺序见 [docs/PROJECT_STATE.md](docs/PROJECT_STATE.md)。
