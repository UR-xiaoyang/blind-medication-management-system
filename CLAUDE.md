# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# 盲人智能用药管理系统 (Blind Medication Management System)

A multi-tier system that helps blind patients take medication on schedule. It pairs an
ESP32 dispenser (firmware) with a web admin backend (Go + Vue 3), a Flutter volunteer
mobile app for emergency response, and 3D-printed mechanical parts (OpenSCAD).

## Quick Start

### Development (Local)
```bash
# Terminal 1: Backend
cd blind-medication-backend && go run cmd/server/main.go

# Terminal 2: Frontend
cd blind-medication-frontend && npm run dev

# Initialize admin (first time only; use a strong password that is never committed)
curl -X POST http://localhost:8080/api/init-admin \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"请设置强密码"}'
```

### Docker Deployment
```bash
# Local development
docker compose -f docker-compose.local.yml up --build -d

# Production (with HTTPS)
cp .env.example .env  # Edit JWT_SECRET and CADDY_DOMAIN
docker compose up -d --build
```

## Repository Layout

| Path | Role |
|------|------|
| `blind-medication-backend/` | Go 1.22 + Gin REST + MQTT broker client + WebSocket hub. SQLite via GORM (no MySQL required at runtime; `init.sql` is a legacy reference). |
| `blind-medication-frontend/` | Vue 3 + Vite + Pinia + Element-Plus admin console. Talks to backend via `/api` (Vite proxy → `:8080`) and `/api/ws` (WebSocket). |
| `firmware/esp32_wroom32_medication/` | **ESP32-WROOM-32 main firmware**. Single Arduino sketch containing L298N motor + encoder + HLK-V20 voice + HC-SR501 PIR + 4 servos + MAX98357 I2S + WiFi AP/STA + Web config + PubSubClient MQTT. Requires `PubSubClient` Arduino library. See `WIRING.md` for pin map. |
| `volunteer_app/` | Flutter (Riverpod + GoRouter) volunteer app. Core feature: 4-level alert system with vibration + alarm ringing. |
| `lab/` | Standalone Python sims (e.g. `door_stuck_simulation.py`). |
| Root `*.scad` / `*.stl` | OpenSCAD mechanical parts for the dispenser mechanism. `推模块拆分方案.md` documents the rack-and-pusher module split. |
| `start.bat` / `stop.bat` | Windows launchers (open pre-built `server.exe` + Vite). |

## Build & Run Commands

### Backend
```bash
cd blind-medication-backend
go mod tidy
go run cmd/server/main.go        # listens on :8080
go build -o server.exe cmd/server/main.go
```
Config is loaded from `config/config.yaml`; override with `CONFIG_PATH=...`. The DB is
auto-created at `data/blind_medication.db` and migrated on startup.

### Frontend
```bash
cd blind-medication-frontend
npm install
npm run dev      # :3000, proxies /api -> :8080
npm run build    # outputs dist/
```

### Volunteer app (Flutter)
```bash
cd volunteer_app
flutter pub get
flutter run
```

### Firmware
Open `firmware/esp32_wroom32_medication/esp32_wroom32_medication.ino` in Arduino IDE
(ESP32 Dev Module, board package `esp32:esp32:esp32`). Install the `PubSubClient`
library via Arduino Library Manager. Motor is gated by `MOTOR_OUTPUT_ENABLED`, voice
UART by `HLK_UART_ENABLED` — keep both safe defaults in place until wiring is verified.

### OpenSCAD parts
Open the `.scad` file in OpenSCAD → F5 preview, F6 render, Export as STL. Shared
parameters for the pusher module live in `推_参数.scad`; other parts use `use <>` /
`include <>` accordingly (see `推模块拆分方案.md`).

## Architecture

### Backend Service Topology
`cmd/server/main.go` is the composition root. It runs each initializer in order;
each failure of DB / config is fatal, but MQTT failure is non-fatal (server keeps
running and the WebSocket hub + simulator-only endpoints stay usable).

- **Config** — `internal/config/config.go` loads `config/config.yaml`.
- **DB** — `internal/model/database.go` opens SQLite at `data/blind_medication.db` and
  calls `AutoMigrate()` for all models in `internal/model/model.go`. On first run it
  also runs `migrateLegacySchedulesToDosePackages()` to convert old `Schedule` rows
  into `DosePackage` + `DosePackageItem` (the new "one dose pack can contain N meds"
  semantic — see model.go comments).
- **Auth** — `internal/middleware/auth.go` provides JWT (HS256) helpers. `AuthMiddleware`
  is applied to everything under `/api` *except* `/login`, `/init-admin`, `/ws`, and
  `/simulator/*`. Init-admin is a one-shot bootstrap (refuses if any admin exists).
- **MQTT** — `internal/service/mqtt.go` is the only path to real devices. It
  subscribes to `blind_medication/devices/+/heartbeat|dispense_result|sensor|status`
  (topic prefix from config), updates in-memory `onlineDevices` and the DB, and
  publishes commands on `devices/{id}/command`. If MQTT is offline, `CheckOverdueDevices`
  goroutine still flips stale devices to offline.
- **WebSocket hub** — `internal/service/websocket_hub.go` is independent of MQTT and
  exists so the in-browser device simulator and admin pages can talk to the server
  without a broker. Clients connect on `/api/ws` (no auth), then send
  `{type:"register", role:"website"|"simulator", device_id:"..."}`. The hub supports
  `Broadcast`, `SendToRole`, `SendToDevice`. MQTT handlers call `GetHub().Broadcast`
  so website pages light up in real time when a result comes back.
- **Simulator bridge** — `internal/handler/simulator.go` is the key glue: it lets a
  browser-side simulator inject a payload (`/api/simulator/publish`) that is *applied
  directly to the DB* via `service.ApplySimulatedMessage`, and optionally forwarded
  to MQTT if `forward_mqtt=true`. This is why the system works with zero hardware.

### Domain Model (`internal/model/model.go`)
- `Patient` (bound 1:1 to a `Device` via `device_id`)
- `Medication` belongs to Patient; has stock counters
- `DosePackage` belongs to Patient, has many `DosePackageItem` (one pack = N meds
  to be taken at one trigger time). Replaces the older `Schedule` model (still
  supported on the wire as a legacy alias).
- `Device` + `DeviceHeartbeat` for ESP32 status & sensor log
- `Report` (BP / glucose / heart-rate / etc.), `NursingRecord`, `MedicationLog`

### HTTP Surface (`internal/handler/router.go`)
Single router file splits into `public` (login/init-admin/simulator/ws) and `auth`
(AuthMiddleware). Each domain (`auth.go`, `patient.go`, `medication.go`, `device.go`,
`report.go`) is one file with the standard CRUD shape — pagination uses
`page` + `page_size` and returns `{data, total, page, page_size}`. The `medication.go`
file also owns `DosePackage` CRUD and the `DispenseMedication` action that calls
`service.SendDispenseCommand` (publishes to MQTT) or `service.SendToDevice` (sends
over WebSocket to a registered simulator with matching `device_id`).

### Frontend Patterns
- `src/api/index.js` — axios instance. Auto-attaches `Bearer ${localStorage.token}`,
  401 → clear storage + redirect to `/login`.
- `src/api/business.js` — flat list of endpoint wrappers. Add new endpoints here.
- `src/stores/user.js` — only Pinia store; everything else is local component state.
- `src/composables/useWebSocket.js` — auto-reconnect wrapper around `/api/ws`, exposes
  `on(type, fn)` and `send(type, data)`. Used by the simulator and device status views.
- `src/router/index.js` — single guard: `localStorage.token` required, except
  `meta.noAuth` (login only). `views/simulator/Index.vue` is the in-browser device
  simulator and is the main consumer of the WS hub.

### Firmware (`firmware/esp32_wroom32_medication/esp32_wroom32_medication.ino`)
Single-file Arduino sketch targeting **ESP32-WROOM-32** (~2166 lines). Key subsystems:
- Motor: L298N channel A on `PIN_ENA=2`, `PIN_IN1=4`, `PIN_IN2=15`, with
  quadrature encoder on `PIN_ENC_A=32/33`. Supports speed control, angle moves
  (encoder-counted), and stall detection.
- Servos: 4 small SG90-class servos via ledc PWM (50 Hz, 16-bit) on
  `SERVO_PINS={14,27,12,21}`. Push-and-return pattern (90° → hold 650 ms → home)
  for dispensing. **All four signal pins avoid GPIO6-11** (WROOM-32 internal flash).
- Voice: HLK-V20 UART1 (`PIN_HLK_RX=16`, `PIN_HLK_TX=17`, 115200) with **explicit
  pin override** (Serial1 default 9/10 is flash). Parser handles 0xAA/0xA5/0xFD
  frame protocol, single-byte command ids (0-8), and ASCII text commands.
- Audio: MAX98357 I2S amp on BCLK/LRCLK/DIN/SD = 26/25/22/23, 16 kHz mono, generated
  tone `AUDIO_AMPLITUDE=9000` (16-bit). WROOM-32 I2S0 pins are **fixed by hardware**;
  these match exactly.
- PIR: HC-SR501 on `PIN_PIR=13` with 120 ms debounce; state changes publish to
  MQTT `blind_medication/devices/<id>/sensor`.
- Network: `WebServer server(80)` exposes `/api/...` HTTP endpoints. Falls back to a configured AP mode if STA fails; `staConnecting`/`staHadConnection` gate the retry loop. Web UI has panels for motor/angle, servos, WiFi setup, and backend HTTP API config (saved to NVS).
- MQTT: `PubSubClient` over WiFi. Publishes to
  `blind_medication/devices/<id>/heartbeat|dispense_result|sensor|status` (matching
  `backend/internal/service/mqtt.go` subscription patterns), subscribes to
  `blind_medication/devices/<id>/command` for `dispense_dose_package` and other
  actions dispatched via the admin console.
- Persistent state via `Preferences` (NVS): `ssid/pass` for STA, `cpr/encsign/aspeed`
  for motor, `mqtt_host/port/id/user/pass` for broker.
- Logging ring buffer `logLines[40]`; `/api/status` returns it for debugging.

### Volunteer App (`volunteer_app/`)
- `main.dart` + `app.dart`: `MaterialApp` with `AuthWrapper` (login gate). All routes
  declared in `app.dart` `routerProvider`; Riverpod is the single state container.
- Features live under `lib/features/{home,tasks,alerts,team,statistics,location,auth}/`,
  each with its own `screens/`, `widgets/`, `providers/`. Shared bits under
  `lib/shared/{models,widgets}/`. Cross-cutting services in
  `lib/core/services/` (notably `alert_service.dart`).
- **Alert system is the headline feature.** See `志愿者APP架构设计方案.md` and
  `TODO.md` for the 4-level severity (`low/medium/high/critical`) alarm model:
  vibration patterns + looping audio + full-screen dialog, with critical alerts
  requiring manual dismissal. The stream is exposed via `AlertService.alertStatusStream`.
- The app depends on `firebase_messaging` for push and `google_maps_flutter` for the
  location feature, but neither backend is wired up in the repo yet — TODO P5 items.

## Conventions & Gotchas

- File names mix English and Chinese; OpenSCAD/parts and a few legacy Go fields
  use Chinese. Backend code is English with Chinese log strings.
- `config/config.yaml` has a real-looking JWT secret and DB password; treat as
  dev-only. Don't commit production secrets here.
- The MQTT topic prefix and broker URL are in YAML; the simulator's `device_id`
  must match what's in the DB.
- The "schedule" vs "dose package" duality: new code should use `DosePackage`.
  Old `/api/schedules` endpoints are kept for compatibility (mapped to
  DosePackage CRUD in handler).
- `data/blind_medication.db` is the dev DB; deleting it resets all state.
- Build artifacts `server.exe`, `server.exe~`, and `dist/` are checked in. Don't
  commit fresh ones without confirming intent.
- WROOM-32 GPIO6-11 are internal flash — never wire anything to them.
- I2S0 pins (26/25/22/23) are fixed by WROOM-32 hardware.
- Servos need external 5V/2A+ power supply, not ESP32 3.3V.
- MQTT is optional — the system works with WebSocket-only communication.
