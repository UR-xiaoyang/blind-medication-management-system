# 项目状态与启动指南

最后核验：2026-10-15（本地 Windows 开发环境）  
仓库状态：`master` 分支尚无提交；所有现有内容均为未跟踪文件。本文是整理后的运行与维护入口，不代表已完成版本发布。

## 1. 已验证的事实

| 项目 | 代码入口 | 本次验证 | 结论 |
| --- | --- | --- | --- |
| 后端 | `blind-medication-backend/cmd/server/main.go` | `go test ./...` | 通过；目前无 Go 测试文件 |
| 管理后台 | `blind-medication-frontend/` | `npm run build` | 通过；存在大于 500 kB 的 Vite chunk 告警 |
| 固件 | `firmware/esp32_wroom32_medication/esp32_wroom32_medication.ino` | `arduino-cli compile --fqbn esp32:esp32:esp32 .` | 通过；Flash 1,165,855 / 1,310,720 bytes（88%），RAM 51,180 / 327,680 bytes（15%） |
| 志愿者端 | `volunteer_app/` | 未运行 | 本机没有 `flutter` 命令 |
| Docker | 根目录 Compose 文件 | 未运行 | 本机没有 `docker` 命令 |

“编译/构建通过”只覆盖代码可构建性；并未验证设备实际接线、舵机供电、MQTT Broker、真实网络、移动端运行或端到端出药流程。

## 2. 架构与事实源

```text
Vue 管理后台 ── HTTP / WebSocket ─┐
                                   │
ESP32 实体设备 ── MQTT ────────────┼── Go 后端 ── SQLite
ESP32 实体设备 ── HTTP + 设备令牌 ─┘

浏览器模拟器 ── /api/ws、/api/simulator/* ── Go 后端
Flutter 志愿者端 ── REST（实时推送尚未落实） ── Go 后端
```

- 后端 HTTP 路由的事实源：`blind-medication-backend/internal/handler/router.go`。
- 数据模型的事实源：`blind-medication-backend/internal/model/model.go`。
- MQTT/WebSocket 消息处理的事实源：`blind-medication-backend/internal/service/`。
- 真实硬件接线的事实源：`firmware/esp32_wroom32_medication/WIRING.md`。
- 固件行为的事实源：`firmware/esp32_wroom32_medication/esp32_wroom32_medication.ino`。
- 移动端未完成范围的事实源：`volunteer_app/TODO.md`。其中的“90% 完成度”是原待办文件的自述，未经过本次运行验证。

## 3. 组件边界

### 后端：`blind-medication-backend/`

- Go 1.25 module；Gin、GORM、SQLite、Paho MQTT、JWT、WebSocket。
- `cmd/server/main.go` 负责组装配置、数据库、MQTT 和路由。
- SQLite 文件默认由应用创建在 `data/blind_medication.db`；不需要 MySQL 才能运行当前代码。
- 公共端点：登录、一次性管理员初始化、WebSocket、浏览器模拟器端点，以及使用 `X-Device-Token` 的实体设备上报端点。
- 其他 `/api/*` 管理端端点使用 JWT。
- 领域新语义是“剂次包”(`DosePackage`)；`/api/schedules` 是兼容旧路径，不应新增依赖。
- MQTT 不可用不会阻止服务进程启动；浏览器模拟器通路可不依赖 MQTT。

### 管理后台：`blind-medication-frontend/`

- Vue 3、Vite、Pinia、Element Plus、ECharts。
- 开发环境代理 `/api` 到 `:8080`。
- 设备管理、患者、药品、剂次包、护理、报告、事件日志及浏览器设备模拟器均已有视图。
- 本次生产构建通过；最大 JS chunk 约 1.19 MB（gzip 约 385 kB），后续性能治理可从路由/图表库拆包入手，但不应在功能整理阶段盲目改动。

### 固件：`firmware/esp32_wroom32_medication/`

- 目标板为 ESP32-WROOM-32，不是 ESP32-S3。
- 单一 `.ino` 包含 L298N 电机与编码器、HLK-V20、四路舵机、PIR、MAX98357、Wi-Fi AP/STA、Web 配置、MQTT 和持久化配置。
- 需要安装 `PubSubClient`；本地 `arduino-cli` 已完成一次成功编译。
- Flash 余量约 145 kB，继续增加功能前先确认体积预算。

### 志愿者端：`volunteer_app/`

- Flutter、Riverpod、GoRouter；核心是四级告警、震动和音频提醒。
- 依赖中含 `firebase_messaging` 与 `google_maps_flutter`，但原待办明确实时功能、地图接入、缓存和测试仍未完成。
- 不应把该应用表述为已完成的真实紧急响应产品，直到在真实 Flutter 环境中完成 `flutter pub get`、`flutter analyze`、构建及后端联调。

### 机械件与实验：根目录 `*.scad` / `*.stl`、`lab/`

- 根目录存在药匣、药盒、推药机构、齿带与齿轮的设计/导出件；中文设计说明包含在根目录与 `齿带修复方案/`。
- `lab/door_stuck_simulation.py` 是独立仿真，不属于线上服务启动路径。

## 4. 启动与验证顺序

### 后端

```bash
cd blind-medication-backend
go test ./...
go run cmd/server/main.go
```

首次数据库为空时，可初始化管理员。请将占位密码替换为强密码，且不要把真实密码写入文档、脚本或版本库。

```bash
curl -X POST http://localhost:8080/api/init-admin \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"请设置强密码"}'
```

### 管理后台

```bash
cd blind-medication-frontend
npm install
npm run build
npm run dev
```

### 固件

```bash
cd firmware/esp32_wroom32_medication
arduino-cli compile --fqbn esp32:esp32:esp32 .
```

上传与真实机械测试必须在完成接线检查、确认外部舵机电源和安全停机策略后进行。

### Flutter（需先安装 Flutter SDK）

```bash
cd volunteer_app
flutter pub get
flutter analyze
flutter test
flutter run
```

### Docker（需先安装 Docker Desktop/Engine）

```bash
# 本地开发部署
docker compose -f docker-compose.local.yml up --build -d

# 生产 Compose：先从 .env.example 创建 .env，并设置安全 JWT_SECRET
docker compose up --build -d
```

## 5. 安全与不可违反的约束

1. GPIO6–11 是 WROOM-32 的内部 Flash 引脚，禁止连接外设。
2. 四个 SG90 类舵机必须使用独立、足够电流的 5V 电源；外部电源必须与 ESP32 共地，不能由 ESP32 3.3V 供电。
3. 固件有电机/语音功能门控，未确认接线时保持安全默认值。
4. `config/config.yaml` 和 `WIRING.md` 中可能包含开发/设备凭据。部署前替换；以后提交前移除或改为占位值。
5. 不提交 `.env`、SQLite 运行数据、固件 NVS 导出、真实 token、Wi-Fi 密码或生产 JWT 密钥。
6. 因根目录目前没有 `.gitignore` 且仓库无初始提交，首次纳入版本控制前必须先建立忽略规则并逐项审阅待加入文件；尤其不能把 `node_modules/`、`.tools/`、`dist/`、日志或构建产物作为源码提交。

## 6. 已知文档与配置冲突

| 主题 | 现状 | 处理原则 |
| --- | --- | --- |
| 后端 Go 版本 | `go.mod` 是 Go 1.25；部分旧说明写 Go 1.22 或 1.24 | 以 `go.mod` 为准 |
| 数据库 | 旧后端 README 仍写 MySQL 配置；现有代码和项目说明显示 SQLite/GORM | 以 `internal/model/database.go` 和运行配置为准，旧 README 需后续更新或归档 |
| 生产反向代理 | `docker-compose.yml` 使用 Nginx；根目录另有未被 Compose 引用的 `Caddyfile` | 当前 Compose 以 Nginx 为准；若选择 Caddy，须配套 compose/部署文档后再启用 |
| 环境变量 | `.env.example` 使用 `APP_DOMAIN`；旧 README 写 `CADDY_DOMAIN`/`CADDY_EMAIL` | 以当前 Compose 和 `.env.example` 为准 |
| 设备连接协议 | 现有固件说明以 MQTT 为主；路由中存在带设备令牌的 HTTP 上报接口 | 部署前选择实际设备路径，并对固件、后台和部署配置执行一次端到端验证 |
| Flutter 地图 | `pubspec.yaml` 有 Google Maps；原 TODO 计划为高德地图 | 先明确目标地图服务和平台配置，再删除另一条未采用路径 |

## 7. 下一轮整理建议（按风险排序）

1. 建立 `.gitignore`，审阅并创建首次提交，只纳入源码、文档、设计源文件和必要配置模板。
2. 更新或归档 `blind-medication-backend/README.md`，消除 MySQL 与旧 API 表述；API 文档从 `router.go` 生成或人工维护为单一事实源。
3. 决定生产入口：Nginx Compose 或 Caddy 二选一，并补齐 HTTPS、域名、端口暴露和备份方案。
4. 安装 Flutter SDK 后完成志愿者端的依赖、分析和构建验证，确认其 REST 模型与现有后端路由是否真的匹配。
5. 明确 ESP32 的真实通信方式（MQTT 或设备令牌 HTTP），使用一个受控测试设备完成“创建设备 → 下发出药 → 结果回传 → 日志确认”的端到端验收。
6. 为后端关键路径增加自动化测试：认证、设备令牌、剂次包、出药命令和模拟器消息落库。
7. 在固件继续扩展前优先清理 Flash 预算，并为传感器/舵机/电机的故障路径做台架测试。

## 8. 文档裁决规则

当 README、旧子目录说明、设计方案和代码互相矛盾时：

1. 对当前可运行行为，以代码、`go.mod`/`package.json`/`pubspec.yaml`、Compose 和已执行命令的输出为准。
2. 对接线与电气限制，以 `WIRING.md` 和固件中的引脚常量为准，并以实际硬件复核为最终依据。
3. 对计划、完成度或未经执行的声明，保留为历史/待验证信息，不升级为当前事实。
4. 修改部署、通信协议或数据模型后，同步更新本文与根 README，避免再次产生多份冲突入口。
