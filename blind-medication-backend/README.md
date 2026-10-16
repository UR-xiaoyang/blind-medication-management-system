# 后端服务

Go + Gin 服务端，负责管理端 REST API、实体设备 HTTP 上报、MQTT 设备消息、WebSocket 实时通知，以及浏览器设备模拟器。

根项目的当前运行状态、完整目录说明与验证边界见 [../docs/PROJECT_STATE.md](../docs/PROJECT_STATE.md)。路由的唯一代码级事实源是 [internal/handler/router.go](internal/handler/router.go)。

## 依赖与存储

- Go 版本：以 `go.mod` 中的 `go 1.25.0` 为准。
- Web：Gin。
- 数据：GORM + SQLite（`github.com/glebarez/sqlite`）。运行时数据库默认位于 `data/blind_medication.db`，首次启动自动迁移。
- 设备实时消息：Paho MQTT 与 WebSocket。
- 管理端认证：JWT；实体设备 HTTP 上报使用 `X-Device-Token`。

当前代码不要求 MySQL。仓库中可能存在的 `init.sql` 或历史 MySQL 说明不属于当前运行路径。

## 本地运行

```bash
cd blind-medication-backend
go test ./...
go run cmd/server/main.go
```

默认监听 `:8080`。配置文件默认读取 `config/config.yaml`，可通过 `CONFIG_PATH` 覆盖。MQTT 初始化失败不会阻断服务启动，但真实 MQTT 设备通信不会可用。

数据库首次为空时，可创建首个管理员：

```bash
curl -X POST http://localhost:8080/api/init-admin \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"请设置强密码"}'
```

该接口只允许在尚无管理员时执行。不要将真实管理员密码、JWT 密钥、设备 Token 或 MQTT 凭据写入版本库。

## API 分组

### 公共接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/login` | 管理员登录 |
| POST | `/api/init-admin` | 首次初始化管理员 |
| GET | `/api/ws` | WebSocket；浏览器/模拟器注册与实时消息 |
| POST | `/api/simulator/publish` | 浏览器模拟器注入设备消息 |
| GET | `/api/simulator/devices` | 模拟器设备数据 |
| GET | `/api/simulator/patients` | 模拟器患者数据 |
| GET | `/api/simulator/dose-packages` | 模拟器剂次包数据 |

### 实体设备 HTTP 上报

以下端点位于 `/api/device`，都要求 `X-Device-Token`：

| 方法 | 路径 |
| --- | --- |
| POST | `/api/device/heartbeat` |
| POST | `/api/device/status` |
| POST | `/api/device/sensor` |
| POST | `/api/device/dispense-result` |
| POST | `/api/device/sos` |

### 管理端接口

其余 `/api/*` 管理接口均需要 JWT。主要资源包括：

- `/profile`、`/stats`
- `/patients`、`/medications`
- `/dose-packages`（新语义）与 `/schedules`（兼容旧路径）
- `/dispense`、`/medication-logs`
- `/devices`、`/devices/:id/token`、`/devices/:id/rotate-token`、`/devices/:id/status`、`/devices/:id/heartbeats`、`/devices/:id/command`
- `/event-logs`、`/nursing-records`

完整方法、路径和鉴权分组请直接查阅 `internal/handler/router.go`；修改路由时必须同步更新此文件或根 README。

## MQTT 主题

当前服务订阅/使用的设备主题以配置中的 topic prefix 为基础，默认结构为：

```text
blind_medication/devices/{device_id}/heartbeat
blind_medication/devices/{device_id}/status
blind_medication/devices/{device_id}/dispense_result
blind_medication/devices/{device_id}/sensor
blind_medication/devices/{device_id}/command
```

MQTT 是真实设备的主消息通路；开发阶段可用 WebSocket 模拟器进行无硬件验证。选择实体设备的 HTTP 上报还是 MQTT 通道前，须让固件、部署配置与后台记录保持一致。

## 验证现状

2026-10-15 本机执行 `go test ./...` 通过；各包目前均显示 `[no test files]`。这说明代码可编译，不代表认证、数据库迁移、MQTT 或出药流程具备自动化覆盖。

