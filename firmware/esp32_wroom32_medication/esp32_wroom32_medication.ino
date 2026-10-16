// ============================================================================
// ESP32-WROOM-32 Medication Dispenser Firmware
// ----------------------------------------------------------------------------
// Single-file Arduino sketch containing the L298N motor + encoder + WiFi/Web
// subsystem, HLK-V20 UART/GPIO voice parser, 4-servo ledc PWM, and the
// backend HTTP API client.
//
// The current transport is HTTP POST to the backend API. The device sends:
//   POST /api/device/heartbeat       — X-Device-Token header
//   POST /api/device/status
//   POST /api/device/sensor
//   POST /api/device/dispense-result
//   POST /api/device/sos
//
// Pin map intentionally avoids GPIO6-11 (WROOM-32 internal flash).
// I2S0 pins are fixed by WROOM-32 hardware: BCLK=26, LRCLK=25, DIN=22.
// Serial1 default pins 9/10 are flash; we override with explicit pins 16/17.
// ============================================================================

#include <Arduino.h>
#include <math.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <driver/i2s.h>

#if __has_include(<esp_arduino_version.h>)
#include <esp_arduino_version.h>
#endif

// ---------- Pin assignments (WROOM-32 safe, no GPIO6-11) ---------------------
static const uint8_t PIN_ENA   = 2;   // L298N ENA (PWM)
static const uint8_t PIN_IN1   = 4;   // L298N IN1
static const uint8_t PIN_IN2   = 15;  // L298N IN2 (strapping, output-only)
static const uint8_t PIN_ENC_A = 32;  // Encoder A (input-only pin)
static const uint8_t PIN_ENC_B = 33;  // Encoder B (input-only pin)

// HC-SR501 PIR motion sensor. OUT -> GPIO13.
static const uint8_t PIN_PIR = 13;
static const bool PIR_ACTIVE_HIGH = true;
static const uint16_t PIR_DEBOUNCE_MS = 120;
static const bool REQUIRE_PIR_FOR_OUTPUT = true;

// HLK-V20 offline voice module. ESP32 receives HLK TX, ESP32 sends HLK RX.
// IMPORTANT: Serial1 default is GPIO9/10 (flash). We MUST override.
static const bool HLK_UART_ENABLED = true;
static const uint8_t PIN_HLK_RX = 16;
static const uint8_t PIN_HLK_TX = 17;
static const uint32_t HLK_BAUD = 115200;
static const uint16_t HLK_FRAME_TIMEOUT_MS = 25;

// HLK-V20 GPIO trigger mode from the offline custom-command table.
// Each rising edge runs one complete action. A held-HIGH input does not shorten
// or extend the timed motor/servo action.
static const bool HLK_GPIO_ENABLED = true;
static const bool HLK_GPIO_ACTIVE_HIGH = true;
static const bool HLK_GPIO_TRIGGER_INITIAL_ACTIVE = false;
static const uint8_t HLK_GPIO_COUNT = 5;
static const int8_t HLK_GPIO_MOTOR_INDEX = 0;  // GPIO34 -> 电机正反序列
static const uint8_t HLK_GPIO_PINS[HLK_GPIO_COUNT] = {34, 5, 18, 19, 35};
// GPIO34->电机正反序列; GPIO5/18/19 -> 舵机 1/2/3; GPIO35 -> 舵机1(一号舵机)
static const uint8_t HLK_GPIO_SERVO_INDEXES[HLK_GPIO_COUNT] = {0, 1, 2, 3, 0};
static const char *HLK_GPIO_NAMES[HLK_GPIO_COUNT] = {
  "GPIO34", "GPIO5", "GPIO18", "GPIO19", "GPIO35"
};
static const uint16_t HLK_GPIO_DEBOUNCE_MS = 50;
static const uint16_t HLK_GPIO_LOCKOUT_MS = 700;

// 4 small servos (SG90-class) for dispensing actions. 5V external supply,
// signal pin only. PWM via ledc.
static const uint8_t SERVO_COUNT = 4;
static const uint8_t SERVO_PINS[SERVO_COUNT] = {14, 27, 12, 21};
static const uint8_t SERVO_HOME_DEG[SERVO_COUNT] = {90, 0, 90, 0};
static const uint8_t SERVO_PUSH_DEG[SERVO_COUNT] = {0, 90, 0, 90};
static const uint16_t SERVO_MIN_US = 500;
static const uint16_t SERVO_MAX_US = 2500;
static const uint32_t SERVO_PWM_FREQ = 50;
static const uint8_t SERVO_PWM_BITS = 16;
static const uint32_t DEFAULT_SERVO_HOLD_MS = 850;
static const uint32_t MAX_SERVO_HOLD_MS = 5000;

// MAX98357 I2S amplifier. WROOM-32 I2S0 pins are fixed.
static const uint8_t PIN_I2S_BCLK = 26;
static const uint8_t PIN_I2S_LRCLK = 25;
static const uint8_t PIN_I2S_DIN = 22;
static const uint8_t PIN_I2S_SD = 23;   // Shutdown/enable
static const uint32_t AUDIO_SAMPLE_RATE = 16000;
static const int16_t AUDIO_AMPLITUDE = 9000;

// Motor PWM.
static const uint32_t PWM_FREQ = 1000;
static const uint8_t PWM_BITS = 8;
static const int MAX_DUTY = (1 << PWM_BITS) - 1;
static const int MOTOR_SEQUENCE_SPEED = 160;
static const uint32_t MOTOR_SEQUENCE_PUSH_MS = 500;
static const uint32_t MOTOR_SEQUENCE_RETURN_MS = 500;

// Keep false while motor is removed or mechanically unsafe.
static const bool MOTOR_OUTPUT_ENABLED = true;

// AP credentials are supplied at build time, never committed to source.
#ifndef MEDBOX_AP_SSID
#define MEDBOX_AP_SSID "ESP32S3-Motor"
#endif
#ifndef MEDBOX_AP_PASS
#define MEDBOX_AP_PASS "CHANGE_ME"
#endif
static const char *AP_SSID = MEDBOX_AP_SSID;
static const char *AP_PASS = MEDBOX_AP_PASS;
static const char *DEFAULT_STA_SSID = "";
static const char *DEFAULT_STA_PASS = "";
static const char *API_DEFAULT_BASE_URL = "";
static const char *API_DEFAULT_DEVICE_ID = "";
static const char *API_DEFAULT_DEVICE_TOKEN = "";

// ---------- Globals ---------------------------------------------------------
static WebServer server(80);
static Preferences prefs;

static volatile int32_t encoderCount = 0;
static volatile uint8_t lastEncoderState = 0;

static int currentSpeed = 0;
static int targetSpeed = 0;
static float encoderCps = 0.0f;
static int32_t countsPerRev = 1440;
static int encoderDirection = 1;
static bool angleMoveActive = false;
static int32_t angleMoveTarget = 0;
static int32_t angleMoveLastAbsRemaining = 0;
static int angleMoveMaxSpeed = 180;
static uint32_t angleMoveLastProgressMs = 0;
static bool motorSequenceActive = false;
static uint8_t motorSequencePhase = 0;
static uint32_t motorSequencePhaseStartedMs = 0;

static bool servoActive[SERVO_COUNT] = {false, false, false, false};
static uint8_t servoCurrentDeg[SERVO_COUNT] = {0, 0, 0, 0};
static uint32_t servoReturnAtMs[SERVO_COUNT] = {0, 0, 0, 0};

static bool staConnecting = false;
static bool staHadConnection = false;
static uint32_t staConnectStartedMs = 0;
static uint32_t lastStaRetryMs = 0;

static HardwareSerial &HLK = Serial1;
static String hlkLine;
static uint32_t hlkCurrentBaud = HLK_BAUD;
static uint32_t hlkLastByteMs = 0;
static uint8_t hlkFrame[8];
static uint8_t hlkFrameLen = 0;
static bool hlkGpioStable[HLK_GPIO_COUNT] = {false, false, false, false};
static bool hlkGpioPending[HLK_GPIO_COUNT] = {false, false, false, false};
static uint32_t hlkGpioPendingSinceMs[HLK_GPIO_COUNT] = {0, 0, 0, 0};
static uint32_t hlkGpioLastFireMs[HLK_GPIO_COUNT] = {0, 0, 0, 0};
static int lastVoiceCommand = -1;
static String lastVoiceRaw = "-";
static uint32_t lastVoiceMs = 0;

static bool audioReady = false;
static bool audioActive = false;
static bool pirMotion = false;
static bool pirRawState = false;
static bool pirPendingState = false;
static uint32_t pirPendingSinceMs = 0;
static uint32_t pirLastMotionMs = 0;
static uint32_t pirLastChangeMs = 0;
static uint8_t outputGateMode = 0;  // 0=auto PIR, 1=manual allow, 2=manual block

// ---- Backend HTTP API state ----
// (NVS keys: api_url, api_device_id, api_token)
static String apiBaseUrl;   // e.g. "https://med.example.com" or "http://192.168.1.10:8080"
static String apiToken;     // X-Device-Token value
static String apiDeviceId;   // device_id used in API requests (NVS: "api_device_id")
static bool   apiConfigured = false;
static uint32_t lastApiHeartbeatMs = 0;
static uint32_t lastApiStatusMs   = 0;

static uint32_t bootMillis = 0;

static const uint8_t LOG_CAPACITY = 40;
static String logLines[LOG_CAPACITY];
static uint8_t logStart = 0;
static uint8_t logCount = 0;

static const int8_t QUAD_TABLE[16] = {
  0, -1, 1, 0,
  1, 0, 0, -1,
  -1, 0, 0, 1,
  0, 1, -1, 0
};

static int32_t readEncoderCount();
static void cancelAngleMove(const String &reason);
static void cancelMotorSequence(const String &reason);
static void startMotorForwardBackSequence(const String &source);
static void motorSequenceUpdate();
static void startAngleMove(float degrees, int32_t cpr, int maxSpeed, int sign);
static void motorSetTarget(int speed, const String &source);
static void printAddresses();
static bool pirAllowsMotion(const String &source, const String &action);
static void handleCommandId(int cmdId, const String &source);
static void servoDispense(uint8_t index, uint32_t holdMs, const String &source);
static void servoAllHome();

// ---- Backend HTTP API ----
static int  apiPostJson(const char *path, const char *jsonBody);
static void apiSendHeartbeat();
static void apiSendStatus();
static void apiSendSensor(float temperature);
static void apiSendDispenseResult(bool success, const char *error, int pkgIndex, const String &slotStates);
static void apiSendSOS(const char *reason);
static void apiUpdate();

// ============================================================================
// HTML UI
// ============================================================================
static const char INDEX_HTML[] PROGMEM = R"rawliteral(
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESP32 WROOM-32 Medication Dispenser</title>
<style>
:root{color-scheme:light;--bg:#f6f7f8;--panel:#fff;--ink:#17202a;--muted:#64748b;--line:#d9dee7;--blue:#2563eb;--green:#15803d;--red:#dc2626;--amber:#b45309}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:system-ui,-apple-system,Segoe UI,Arial,sans-serif;letter-spacing:0}
main{width:min(1100px,100%);margin:0 auto;padding:18px}
header{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;margin-bottom:14px}
h1{font-size:24px;line-height:1.15;margin:0}
h2{font-size:16px;margin:0 0 12px}
.sub{color:var(--muted);font-size:13px;margin-top:4px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}
.span{grid-column:1/-1}
.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.field{display:grid;gap:6px;margin:10px 0}
label{font-size:12px;color:var(--muted);font-weight:650}
input,select,button{height:40px;border-radius:8px;border:1px solid var(--line);background:#fff;color:var(--ink);font:inherit}
input,select{padding:0 10px;min-width:0}
input[type=range]{padding:0;width:100%;accent-color:var(--blue)}
button{padding:0 12px;font-weight:700;cursor:pointer}
button.primary{background:var(--blue);border-color:var(--blue);color:#fff}
button.good{background:var(--green);border-color:var(--green);color:#fff}
button.stop{background:var(--red);border-color:var(--red);color:#fff}
button.warn{background:#fff7ed;border-color:#fed7aa;color:var(--amber)}
button:disabled{opacity:.55;cursor:wait}
.statgrid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}
.stat{border:1px solid var(--line);border-radius:8px;padding:10px;background:#fbfcfe;min-height:74px}
.stat .k{font-size:12px;color:var(--muted);font-weight:700}
.stat .v{font-size:20px;font-weight:800;margin-top:6px;overflow-wrap:anywhere}
.wide{grid-column:span 2}
.speedbox{display:grid;grid-template-columns:1fr 94px;gap:10px;align-items:center}
#logs{margin:0;min-height:190px;max-height:320px;overflow:auto;background:#0f172a;color:#dbeafe;border-radius:8px;padding:12px;font:12px/1.45 Consolas,Monaco,monospace;white-space:pre-wrap}
.pill{display:inline-flex;align-items:center;gap:6px;height:28px;padding:0 10px;border-radius:999px;border:1px solid var(--line);background:#fff;color:var(--muted);font-size:12px;font-weight:750}
.ok{color:var(--green)}.bad{color:var(--red)}
@media (max-width:760px){main{padding:12px}.grid{grid-template-columns:1fr}.statgrid{grid-template-columns:1fr 1fr}.wide{grid-column:auto}header{display:block}.speedbox{grid-template-columns:1fr 76px}}
</style>
</head>
<body>
<main>
  <header>
    <div>
      <h1>ESP32 WROOM-32 Medication Dispenser</h1>
      <div class="sub">AP: ESP32S3-Motor; set a unique AP password before deployment, then open http://192.168.4.1</div>
    </div>
    <span id="netPill" class="pill">Loading</span>
  </header>

  <section class="panel span">
    <div class="statgrid">
      <div class="stat"><div class="k">Motor</div><div class="v" id="speed">0</div></div>
      <div class="stat"><div class="k">Target</div><div class="v" id="target">0</div></div>
      <div class="stat"><div class="k">Encoder</div><div class="v" id="encoder">0</div></div>
      <div class="stat"><div class="k">Counts/s</div><div class="v" id="cps">0.0</div></div>
      <div class="stat"><div class="k">Angle Move</div><div class="v" id="angleState">Idle</div></div>
      <div class="stat"><div class="k">Remaining</div><div class="v" id="angleRemaining">0</div></div>
      <div class="stat wide"><div class="k">STA IP</div><div class="v" id="staIp">-</div></div>
      <div class="stat wide"><div class="k">AP IP</div><div class="v" id="apIp">192.168.4.1</div></div>
      <div class="stat wide"><div class="k">Voice</div><div class="v" id="voiceState">-</div></div>
      <div class="stat wide"><div class="k">Voice GPIO</div><div class="v" id="voiceGpio">-</div></div>
      <div class="stat wide"><div class="k">Audio</div><div class="v" id="audioState">Off</div></div>
      <div class="stat wide"><div class="k">PIR Motion</div><div class="v" id="pirState">-</div></div>
      <div class="stat wide"><div class="k">PIR Last Seen</div><div class="v" id="pirLastSeen">-</div></div>
      <div class="stat wide"><div class="k">Output Gate</div><div class="v" id="gateState">-</div></div>
      <div class="stat wide"><div class="k">Backend</div><div class="v" id="mqttState">-</div></div>
      <div class="stat wide"><div class="k">Uptime</div><div class="v" id="uptime">0s</div></div>
    </div>
  </section>

  <div class="grid">
    <section class="panel">
      <h2>Motor Test</h2>
      <div class="field">
        <label for="speedRange">Speed -255..255</label>
        <div class="speedbox">
          <input id="speedRange" type="range" min="-255" max="255" value="0">
          <input id="speedInput" type="number" min="-255" max="255" value="0">
        </div>
      </div>
      <div class="row">
        <button class="primary" onclick="applySpeed()">Set</button>
        <button onclick="quick(60)">+60</button>
        <button onclick="quick(120)">+120</button>
        <button onclick="quick(-60)">-60</button>
        <button onclick="quick(-120)">-120</button>
        <button class="stop" onclick="stopMotor()">Stop</button>
        <button class="warn" onclick="zeroEncoder()">Zero</button>
      </div>
    </section>

    <section class="panel">
      <h2>Angle Move</h2>
      <div class="field">
        <label for="countsPerRev">Counts per output revolution</label>
        <input id="countsPerRev" type="number" min="1" max="200000" value="1440">
      </div>
      <div class="field">
        <label for="encoderSign">Encoder direction</label>
        <select id="encoderSign">
          <option value="1">Normal</option>
          <option value="-1">Invert</option>
        </select>
      </div>
      <div class="field">
        <label for="angleSpeed">Max speed</label>
        <input id="angleSpeed" type="number" min="60" max="255" value="180">
      </div>
      <div class="field">
        <label for="angleDeg">Degrees</label>
        <input id="angleDeg" type="number" min="-3600" max="3600" step="1" value="90">
      </div>
      <div class="row">
        <button class="primary" onclick="rotateAngle()">Rotate</button>
        <button onclick="anglePreset(90)">+90</button>
        <button onclick="anglePreset(180)">+180</button>
        <button onclick="anglePreset(360)">+360</button>
        <button onclick="anglePreset(-90)">-90</button>
        <button class="stop" onclick="stopMotor()">Stop</button>
      </div>
    </section>

    <section class="panel">
      <h2>Servos</h2>
      <div class="field">
        <label for="servoIdx">Target servo</label>
        <select id="servoIdx">
          <option value="1">Servo 1 (GPIO14)</option>
          <option value="2">Servo 2 (GPIO27)</option>
          <option value="3">Servo 3 (GPIO12)</option>
          <option value="4">Servo 4 (GPIO21)</option>
        </select>
      </div>
      <div class="field">
        <label for="servoAngle">Angle (0-180)</label>
        <input id="servoAngle" type="number" min="0" max="180" value="90">
      </div>
      <div class="field">
        <label for="servoHold">Hold ms (push mode)</label>
        <input id="servoHold" type="number" min="100" max="5000" value="850">
      </div>
      <div class="row">
        <button class="primary" onclick="servoPush()">Push</button>
        <button onclick="servoSetAngle()">Set Angle</button>
        <button class="stop" onclick="servoHomeAll()">Home All</button>
        <button class="warn" onclick="servoBeep()">Beep</button>
      </div>
    </section>

    <section class="panel">
      <h2>Output Gate</h2>
      <div class="field">
        <label for="gateMode">Servo and motor permission</label>
        <select id="gateMode">
          <option value="auto">Auto by PIR</option>
          <option value="allow">Manual allow</option>
          <option value="block">Manual block</option>
        </select>
      </div>
      <div class="row">
        <button class="primary" onclick="saveGateMode()">Apply</button>
      </div>
    </section>

    <section class="panel">
      <h2>WiFi Setup</h2>
      <form id="wifiForm">
        <div class="field">
          <label for="ssidList">Nearby networks</label>
          <div class="row">
            <select id="ssidList" style="flex:1"></select>
            <button id="scanBtn" type="button" onclick="scanWifi()">Scan</button>
          </div>
        </div>
        <div class="field">
          <label for="ssid">SSID</label>
          <input id="ssid" autocomplete="off">
        </div>
        <div class="field">
          <label for="pass">Password</label>
          <input id="pass" type="password" autocomplete="current-password">
        </div>
        <div class="row">
          <button class="good" type="submit">Save and Connect</button>
          <button type="button" class="warn" onclick="forgetWifi()">Forget</button>
        </div>
      </form>
    </section>

    <section class="panel">
      <h2>Backend HTTP API</h2>
      <p style="font-size:12px;color:#64748b;margin:0 0 8px">
        ESP32 上报心跳/出药/SOS 到后端。从管理后台 → 设备管理 → Token 页面获取。
      </p>
      <form id="apiForm">
        <div class="field">
          <label for="apiUrl">Backend API 地址</label>
          <input id="apiUrl" autocomplete="off" placeholder="http://backend-host:8080">
        </div>
        <div class="field">
          <label for="apiDeviceId">Device ID</label>
          <input id="apiDeviceId" autocomplete="off" placeholder="在后台注册的设备 ID">
        </div>
        <div class="field">
          <label for="apiToken">X-Device-Token</label>
          <input id="apiToken" type="password" autocomplete="off" placeholder="从后台复制的 64 位 hex token">
        </div>
        <div class="row">
          <button class="good" type="submit">Save and Connect</button>
          <button type="button" class="warn" onclick="forgetApi()">Clear</button>
        </div>
      </form>
    </section>

    <section class="panel">
      <h2>Voice / Audio</h2>
      <div class="field">
        <label for="voiceCmd">HLK-V20 command id</label>
        <input id="voiceCmd" type="number" min="0" max="99" value="1">
      </div>
      <div class="row">
        <button class="primary" onclick="testVoice()">Run</button>
        <button onclick="voicePreset(1)">CMD 1</button>
        <button onclick="voicePreset(2)">CMD 2</button>
        <button onclick="voicePreset(0)">Stop</button>
        <button onclick="voicePreset(8)">Home</button>
        <button class="good" onclick="testBeep()">Beep</button>
      </div>
    </section>

    <section class="panel span">
      <h2>Logs</h2>
      <pre id="logs"></pre>
    </section>
  </div>
</main>

<script>
const $ = id => document.getElementById(id);
const range = $('speedRange');
const input = $('speedInput');
range.addEventListener('input', () => input.value = range.value);
input.addEventListener('input', () => range.value = input.value);
$('ssidList').addEventListener('change', e => { if (e.target.value) $('ssid').value = e.target.value; });
$('wifiForm').addEventListener('submit', async e => {
  e.preventDefault();
  const body = new URLSearchParams({ssid:$('ssid').value, pass:$('pass').value});
  await fetch('/api/wifi', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  setTimeout(refresh, 800);
});
// API form submission
$('apiForm').addEventListener('submit', async e => {
  e.preventDefault();
  const body = new URLSearchParams({
    url:   $('apiUrl').value,
    id:    $('apiDeviceId').value,
    token: $('apiToken').value
  });
  await fetch('/api/api-config', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  setTimeout(refresh, 1200);
});
window.forgetApi = async () => { await fetch('/api/api-config/clear', {method:'POST'}); refresh(); };

const json = async (url, options) => {
  const r = await fetch(url, options);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
};

window.scanWifi = async () => {
  const btn = $('scanBtn');
  btn.disabled = true;
  btn.textContent = 'Scanning';
  try {
    const data = await json('/api/scan');
    const list = $('ssidList');
    list.innerHTML = '';
    for (const n of data.networks) {
      const opt = document.createElement('option');
      opt.value = n.ssid;
      opt.textContent = `${n.ssid || '(hidden)'}  ${n.rssi} dBm  ${n.enc}`;
      list.appendChild(opt);
    }
    if (data.networks.length && !$('ssid').value) $('ssid').value = data.networks[0].ssid;
  } finally {
    btn.disabled = false;
    btn.textContent = 'Scan';
  }
};

const setSpeed = async (v) => {
  v = Math.max(-255, Math.min(255, parseInt(v || 0, 10)));
  range.value = v;
  input.value = v;
  await fetch('/api/motor', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({speed:v})});
  refresh();
};
window.applySpeed = () => { setSpeed(input.value); };
window.quick = (v) => { setSpeed(v); };
window.stopMotor = async () => { await setSpeed(0); };
window.zeroEncoder = async () => { await fetch('/api/zero', {method:'POST'}); refresh(); };
window.forgetWifi = async () => { await fetch('/api/wifi/clear', {method:'POST'}); refresh(); };
window.forgetMqtt = async () => { await fetch('/api/api-config/clear', {method:'POST'}); refresh(); };
window.testBeep = async () => { await fetch('/api/audio/beep', {method:'POST'}); refresh(); };
window.testVoice = async () => {
  await fetch('/api/voice', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({cmd:$('voiceCmd').value})});
  refresh();
};
window.voicePreset = (cmd) => {
  $('voiceCmd').value = cmd;
  testVoice();
};
window.rotateAngle = async (deg) => {
  const degrees = deg ?? $('angleDeg').value;
  const body = new URLSearchParams({
    degrees,
    cpr: $('countsPerRev').value,
    speed: $('angleSpeed').value,
    sign: $('encoderSign').value
  });
  await fetch('/api/angle', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  refresh();
};
window.anglePreset = (deg) => {
  $('angleDeg').value = deg;
  rotateAngle(deg);
};
window.servoPush = async () => {
  const body = new URLSearchParams({
    index: $('servoIdx').value,
    holdMs: $('servoHold').value
  });
  await fetch('/api/servo/push', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  refresh();
};
window.servoSetAngle = async () => {
  const body = new URLSearchParams({
    index: $('servoIdx').value,
    angle: $('servoAngle').value
  });
  await fetch('/api/servo/angle', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  refresh();
};
window.servoHomeAll = async () => {
  await fetch('/api/servo/home', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({index:'all'})});
  refresh();
};
window.servoBeep = async () => { await testBeep(); };
window.saveGateMode = async () => {
  const body = new URLSearchParams({mode:$('gateMode').value});
  await fetch('/api/output-gate', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body});
  refresh();
};

const refresh = async () => {
  try {
    const s = await json('/api/status');
    $('speed').textContent = s.speed;
    $('target').textContent = s.target;
    $('encoder').textContent = s.encoder;
    $('cps').textContent = s.cps.toFixed(1);
    $('angleState').textContent = s.angle.active ? 'Run' : 'Idle';
    $('angleRemaining').textContent = s.angle.remaining;
    if (document.activeElement !== $('countsPerRev')) $('countsPerRev').value = s.angle.cpr;
    if (document.activeElement !== $('angleSpeed')) $('angleSpeed').value = s.angle.maxSpeed;
    if (document.activeElement !== $('encoderSign')) $('encoderSign').value = s.angle.sign;
    $('staIp').textContent = s.sta.connected ? s.sta.ip : '-';
    $('apIp').textContent = s.ap.ip;
    $('voiceState').textContent = `${s.voice.command} ${s.voice.raw} (${s.voice.baud} baud)`;
    $('voiceGpio').textContent = s.voice.gpio.map(g => `${g.name}:${g.active ? 1 : 0}`).join(' ');
    $('audioState').textContent = s.audio.ready ? (s.audio.active ? 'Playing' : 'Ready') : 'Off';
    $('pirState').textContent = s.pir.motion ? 'Detected' : 'Clear';
    $('pirLastSeen').textContent = s.pir.lastMotionMs > 0 ? `${Math.round(s.pir.lastMotionMs / 1000)}s ago` : '-';
    $('gateState').textContent = s.outputGate.label;
    if (document.activeElement !== $('gateMode')) $('gateMode').value = s.outputGate.mode;
    $('mqttState').textContent = s.api.configured
      ? `HTTP API configured for ${s.api.deviceId}`
      : 'Not configured';
    $('uptime').textContent = `${Math.round(s.uptimeSec)}s`;
    $('logs').textContent = s.logs.join('\n');
    if (document.activeElement !== $('apiUrl')) $('apiUrl').value = s.api.configured ? s.api.baseUrl : '';
    if (document.activeElement !== $('apiDeviceId')) $('apiDeviceId').value = s.api.deviceId || '';
    if (document.activeElement !== $('apiToken')) { /* don't overwrite during typing */ }
    const pill = $('netPill');
    pill.textContent = s.sta.connected ? `STA ${s.sta.ssid} ${s.sta.rssi} dBm` : 'AP mode';
    pill.className = 'pill ' + (s.sta.connected ? 'ok' : 'bad');
  } catch (e) {
    $('netPill').textContent = 'Offline';
    $('netPill').className = 'pill bad';
  }
};
refresh();
scanWifi().catch(()=>{});
setInterval(refresh, 1000);
</script>
</body>
</html>
)rawliteral";

// ============================================================================
// LEDC PWM (Arduino-ESP32 v2.x and v3.x compatible)
// ============================================================================
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
static void pwmBegin() {
  ledcAttach(PIN_ENA, PWM_FREQ, PWM_BITS);
}
static void pwmWriteDuty(int duty) {
  ledcWrite(PIN_ENA, constrain(duty, 0, MAX_DUTY));
}
static void servoPwmBegin() {
  for (uint8_t i = 0; i < SERVO_COUNT; ++i) {
    ledcAttach(SERVO_PINS[i], SERVO_PWM_FREQ, SERVO_PWM_BITS);
  }
}
static void servoWritePulseUs(uint8_t index, uint16_t pulseUs) {
  if (index >= SERVO_COUNT) return;
  uint32_t maxDuty = (1UL << SERVO_PWM_BITS) - 1;
  uint32_t duty = ((uint32_t)pulseUs * maxDuty) / 20000UL;
  ledcWrite(SERVO_PINS[index], duty);
}
#else
static const uint8_t CH_ENA = 0;
static const uint8_t SERVO_CHANNELS[SERVO_COUNT] = {1, 2, 3, 4};

static void pwmBegin() {
  ledcSetup(CH_ENA, PWM_FREQ, PWM_BITS);
  ledcAttachPin(PIN_ENA, CH_ENA);
}
static void pwmWriteDuty(int duty) {
  ledcWrite(CH_ENA, constrain(duty, 0, MAX_DUTY));
}
static void servoPwmBegin() {
  for (uint8_t i = 0; i < SERVO_COUNT; ++i) {
    ledcSetup(SERVO_CHANNELS[i], SERVO_PWM_FREQ, SERVO_PWM_BITS);
    ledcAttachPin(SERVO_PINS[i], SERVO_CHANNELS[i]);
  }
}
static void servoWritePulseUs(uint8_t index, uint16_t pulseUs) {
  if (index >= SERVO_COUNT) return;
  uint32_t maxDuty = (1UL << SERVO_PWM_BITS) - 1;
  uint32_t duty = ((uint32_t)pulseUs * maxDuty) / 20000UL;
  ledcWrite(SERVO_CHANNELS[index], duty);
}
#endif

// ============================================================================
// JSON / Logging helpers
// ============================================================================
static String jsonEscape(const String &value) {
  String out;
  out.reserve(value.length() + 8);
  for (size_t i = 0; i < value.length(); ++i) {
    char c = value[i];
    if (c == '\"') out += "\\\"";
    else if (c == '\\') out += "\\\\";
    else if (c == '\n') out += "\\n";
    else if (c == '\r') out += "\\r";
    else if (c == '\t') out += "\\t";
    else out += c;
  }
  return out;
}

static void addLog(const String &message) {
  String line = "[" + String(millis() / 1000) + "s] " + message;
  uint8_t idx = (logStart + logCount) % LOG_CAPACITY;
  if (logCount == LOG_CAPACITY) {
    logLines[logStart] = line;
    logStart = (logStart + 1) % LOG_CAPACITY;
  } else {
    logLines[idx] = line;
    ++logCount;
  }
  Serial.println(line);
}

static String logsJson() {
  String out = "[";
  for (uint8_t i = 0; i < logCount; ++i) {
    if (i) out += ",";
    uint8_t idx = (logStart + i) % LOG_CAPACITY;
    out += "\"";
    out += jsonEscape(logLines[idx]);
    out += "\"";
  }
  out += "]";
  return out;
}

static String authName(wifi_auth_mode_t mode) {
  switch (mode) {
    case WIFI_AUTH_OPEN: return "open";
    case WIFI_AUTH_WEP: return "WEP";
    case WIFI_AUTH_WPA_PSK: return "WPA";
    case WIFI_AUTH_WPA2_PSK: return "WPA2";
    case WIFI_AUTH_WPA_WPA2_PSK: return "WPA/WPA2";
    case WIFI_AUTH_WPA2_ENTERPRISE: return "WPA2-E";
    case WIFI_AUTH_WPA3_PSK: return "WPA3";
    case WIFI_AUTH_WPA2_WPA3_PSK: return "WPA2/WPA3";
    default: return "secure";
  }
}

// ============================================================================
// Audio (MAX98357 I2S prompt tones)
// ============================================================================
enum {
  CUE_READY,
  CUE_OK,
  CUE_STOP,
  CUE_ERROR,
  CUE_VOICE,
  CUE_WIFI
};

static const float AUDIO_TWO_PI = 6.28318530718f;
static const uint16_t CUE_READY_STEPS[][3] = {{660, 90, 45}, {880, 130, 0}};
static const uint16_t CUE_OK_STEPS[][3] = {{880, 90, 25}, {1040, 90, 0}};
static const uint16_t CUE_STOP_STEPS[][3] = {{440, 160, 0}};
static const uint16_t CUE_ERROR_STEPS[][3] = {{220, 120, 35}, {180, 180, 0}};
static const uint16_t CUE_VOICE_STEPS[][3] = {{740, 60, 25}, {980, 70, 0}};
static const uint16_t CUE_WIFI_STEPS[][3] = {{520, 70, 25}, {660, 70, 25}, {820, 100, 0}};

static const uint16_t (*audioPattern)[3] = nullptr;
static uint8_t audioPatternLen = 0;
static uint8_t audioStepIndex = 0;
static bool audioGapActive = false;
static uint32_t audioStepStartedMs = 0;
static float audioPhase = 0.0f;

static void audioStartPattern(const uint16_t pattern[][3], uint8_t len) {
  if (len == 0 || pattern == nullptr) {
    audioPattern = nullptr;
    audioPatternLen = 0;
    audioActive = false;
    return;
  }
  audioPattern = pattern;
  audioPatternLen = len;
  audioStepIndex = 0;
  audioGapActive = false;
  audioStepStartedMs = millis();
  audioPhase = 0.0f;
  audioActive = true;
}

static void audioStartCue(uint8_t cue) {
  switch (cue) {
    case CUE_READY: audioStartPattern(CUE_READY_STEPS, sizeof(CUE_READY_STEPS) / sizeof(CUE_READY_STEPS[0])); break;
    case CUE_OK:    audioStartPattern(CUE_OK_STEPS,    sizeof(CUE_OK_STEPS)    / sizeof(CUE_OK_STEPS[0]));    break;
    case CUE_STOP:  audioStartPattern(CUE_STOP_STEPS,  sizeof(CUE_STOP_STEPS)  / sizeof(CUE_STOP_STEPS[0]));  break;
    case CUE_ERROR: audioStartPattern(CUE_ERROR_STEPS, sizeof(CUE_ERROR_STEPS) / sizeof(CUE_ERROR_STEPS[0])); break;
    case CUE_VOICE: audioStartPattern(CUE_VOICE_STEPS, sizeof(CUE_VOICE_STEPS) / sizeof(CUE_VOICE_STEPS[0])); break;
    case CUE_WIFI:  audioStartPattern(CUE_WIFI_STEPS,  sizeof(CUE_WIFI_STEPS)  / sizeof(CUE_WIFI_STEPS[0]));  break;
  }
}

static void audioBegin() {
  pinMode(PIN_I2S_SD, OUTPUT);
  digitalWrite(PIN_I2S_SD, HIGH);

  i2s_config_t config = {};
  config.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
  config.sample_rate = AUDIO_SAMPLE_RATE;
  config.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  config.channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT;
  config.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  config.intr_alloc_flags = 0;
  config.dma_buf_count = 4;
  config.dma_buf_len = 128;
  config.use_apll = false;
  config.tx_desc_auto_clear = true;
  config.fixed_mclk = 0;

  i2s_pin_config_t pins = {};
  pins.mck_io_num = I2S_PIN_NO_CHANGE;
  pins.bck_io_num = PIN_I2S_BCLK;
  pins.ws_io_num = PIN_I2S_LRCLK;
  pins.data_out_num = PIN_I2S_DIN;
  pins.data_in_num = I2S_PIN_NO_CHANGE;

  esp_err_t err = i2s_driver_install(I2S_NUM_0, &config, 0, nullptr);
  if (err != ESP_OK) {
    addLog("I2S driver failed: " + String((int)err));
    audioReady = false;
    return;
  }
  err = i2s_set_pin(I2S_NUM_0, &pins);
  if (err != ESP_OK) {
    addLog("I2S pins failed: " + String((int)err));
    audioReady = false;
    return;
  }
  i2s_zero_dma_buffer(I2S_NUM_0);
  audioReady = true;
  addLog("MAX98357 I2S ready: BCLK " + String(PIN_I2S_BCLK) + ", LRCLK " + String(PIN_I2S_LRCLK) + ", DIN " + String(PIN_I2S_DIN));
}

static void audioWriteTone(uint16_t hz) {
  static int16_t samples[128 * 2];
  for (size_t frame = 0; frame < 128; ++frame) {
    audioPhase += AUDIO_TWO_PI * (float)hz / (float)AUDIO_SAMPLE_RATE;
    if (audioPhase >= AUDIO_TWO_PI) audioPhase -= AUDIO_TWO_PI;
    int16_t sample = (int16_t)(sinf(audioPhase) * AUDIO_AMPLITUDE);
    samples[frame * 2] = sample;
    samples[frame * 2 + 1] = sample;
  }
  size_t bytesWritten = 0;
  i2s_write(I2S_NUM_0, samples, sizeof(samples), &bytesWritten, 0);
}

static void audioUpdate() {
  if (!audioReady || !audioActive || audioPattern == nullptr) return;
  const uint16_t *step = audioPattern[audioStepIndex];
  uint32_t now = millis();
  uint16_t phaseMs = audioGapActive ? step[2] : step[1];
  if (now - audioStepStartedMs >= phaseMs) {
    if (!audioGapActive && step[2] > 0) {
      audioGapActive = true;
      audioStepStartedMs = now;
      return;
    }
    ++audioStepIndex;
    audioGapActive = false;
    audioStepStartedMs = now;
    audioPhase = 0.0f;
    if (audioStepIndex >= audioPatternLen) {
      audioPattern = nullptr;
      audioPatternLen = 0;
      audioActive = false;
      i2s_zero_dma_buffer(I2S_NUM_0);
      return;
    }
  }
  if (!audioGapActive && audioPattern[audioStepIndex][0] > 0) {
    audioWriteTone(audioPattern[audioStepIndex][0]);
  }
}

// ============================================================================
// HLK-V20 UART parser
// ============================================================================
static void hlkBegin(uint32_t baud = HLK_BAUD) {
  pinMode(PIN_HLK_RX, INPUT_PULLUP);
  pinMode(PIN_HLK_TX, OUTPUT);
  digitalWrite(PIN_HLK_TX, HIGH);
  if (!HLK_UART_ENABLED) {
    addLog("HLK-V20 UART disabled (HLK_UART_ENABLED=false)");
    return;
  }
  hlkLine.reserve(48);
  HLK.begin(baud, SERIAL_8N1, PIN_HLK_RX, PIN_HLK_TX);
  hlkCurrentBaud = baud;
  hlkFrameLen = 0;
  hlkLine = "";
  addLog("HLK-V20 UART ready: RX " + String(PIN_HLK_RX) + ", TX " + String(PIN_HLK_TX) + ", baud " + String(hlkCurrentBaud));
}

static bool hlkReadGpio(uint8_t index) {
  bool high = digitalRead(HLK_GPIO_PINS[index]) == HIGH;
  return HLK_GPIO_ACTIVE_HIGH ? high : !high;
}

static void hlkGpioBegin() {
  if (!HLK_GPIO_ENABLED) {
    addLog("HLK-V20 GPIO triggers disabled");
    return;
  }
  uint32_t now = millis();
  for (uint8_t i = 0; i < HLK_GPIO_COUNT; ++i) {
    pinMode(HLK_GPIO_PINS[i], INPUT);
    bool raw = hlkReadGpio(i);
    hlkGpioStable[i] = raw;
    hlkGpioPending[i] = raw;
    hlkGpioPendingSinceMs[i] = now;
    hlkGpioLastFireMs[i] = 0;
  }
  addLog("HLK-V20 GPIO ready: GPIO34->motor, GPIO5/18/19->servo GPIO27/12/21, GPIO35->servo GPIO14");
  if (HLK_GPIO_TRIGGER_INITIAL_ACTIVE) {
    for (uint8_t i = 0; i < HLK_GPIO_COUNT; ++i) {
      if (hlkGpioStable[i]) {
        hlkGpioLastFireMs[i] = now;
        lastVoiceRaw = String(HLK_GPIO_NAMES[i]) + " already HIGH";
        if (i == HLK_GPIO_MOTOR_INDEX) {
          lastVoiceCommand = 1;
          lastVoiceMs = now;
          startMotorForwardBackSequence("HLK-V20-GPIO");
        } else {
          lastVoiceCommand = (int)HLK_GPIO_SERVO_INDEXES[i] + 1;
          lastVoiceMs = now;
          servoDispense(HLK_GPIO_SERVO_INDEXES[i], DEFAULT_SERVO_HOLD_MS, "HLK-V20-GPIO");
        }
        audioStartCue(CUE_VOICE);
      }
    }
  }
}

static void hlkGpioUpdate() {
  if (!HLK_GPIO_ENABLED) return;
  uint32_t now = millis();
  for (uint8_t i = 0; i < HLK_GPIO_COUNT; ++i) {
    bool raw = hlkReadGpio(i);
    if (raw != hlkGpioPending[i]) {
      hlkGpioPending[i] = raw;
      hlkGpioPendingSinceMs[i] = now;
    }
    if (raw == hlkGpioStable[i] || now - hlkGpioPendingSinceMs[i] < HLK_GPIO_DEBOUNCE_MS) {
      continue;
    }

    bool previous = hlkGpioStable[i];
    hlkGpioStable[i] = raw;
    if (!previous && raw && (hlkGpioLastFireMs[i] == 0 || now - hlkGpioLastFireMs[i] >= HLK_GPIO_LOCKOUT_MS)) {
      hlkGpioLastFireMs[i] = now;
      lastVoiceRaw = String(HLK_GPIO_NAMES[i]) + " HIGH";
      lastVoiceCommand = i == HLK_GPIO_MOTOR_INDEX ? 1 : (int)HLK_GPIO_SERVO_INDEXES[i] + 1;
      lastVoiceMs = now;
      if (i == HLK_GPIO_MOTOR_INDEX) {
        startMotorForwardBackSequence("HLK-V20-GPIO");
      } else {
        servoDispense(HLK_GPIO_SERVO_INDEXES[i], DEFAULT_SERVO_HOLD_MS, "HLK-V20-GPIO");
      }
      audioStartCue(CUE_VOICE);
    }
  }
}

static String hexByte(uint8_t value) {
  const char *hex = "0123456789ABCDEF";
  String out = "0x";
  out += hex[(value >> 4) & 0x0F];
  out += hex[value & 0x0F];
  return out;
}

static bool isAsciiDigit(char value) { return value >= '0' && value <= '9'; }

static int extractFirstInt(const String &text, bool &found) {
  found = false;
  for (uint16_t i = 0; i < text.length(); ++i) {
    bool sign = (text[i] == '-' || text[i] == '+') && i + 1 < text.length() && isAsciiDigit(text[i + 1]);
    if (isAsciiDigit(text[i]) || sign) {
      uint16_t end = i + 1;
      while (end < text.length() && isAsciiDigit(text[end])) ++end;
      found = true;
      return text.substring(i, end).toInt();
    }
  }
  return -1;
}

static int hlkCommandFromText(const String &text) {
  bool foundDigit = false;
  int digitCmd = extractFirstInt(text, foundDigit);
  if (foundDigit) return digitCmd;

  String lower = text;
  lower.toLowerCase();
  if (lower.indexOf("stop") >= 0 || lower.indexOf("halt") >= 0) return 0;
  if (lower.indexOf("servo1") >= 0 || lower.indexOf("slot1") >= 0) return 1;
  if (lower.indexOf("servo2") >= 0 || lower.indexOf("slot2") >= 0) return 2;
  if (lower.indexOf("servo3") >= 0 || lower.indexOf("slot3") >= 0) return 3;
  if (lower.indexOf("servo4") >= 0 || lower.indexOf("slot4") >= 0) return 4;
  if (lower.indexOf("forward") >= 0) return 5;
  if (lower.indexOf("back") >= 0 || lower.indexOf("reverse") >= 0) return 6;
  if (lower.indexOf("zero") >= 0) return 7;
  if (lower.indexOf("home") >= 0) return 8;
  return -1;
}

static void hlkDispatchCommand(int cmdId, const String &raw, const String &source) {
  if (cmdId < 0 || cmdId > 20) {
    addLog(source + " ignored command " + String(cmdId) + " raw=" + raw);
    return;
  }
  lastVoiceRaw = raw;
  if (cmdId == 5) {
    lastVoiceCommand = cmdId;
    lastVoiceMs = millis();
    addLog(source + " command 5 -> servo 2 GPIO27");
    servoDispense(1, DEFAULT_SERVO_HOLD_MS, source);
    audioStartCue(CUE_VOICE);
    return;
  }
  handleCommandId(cmdId, source);
}

static void hlkHandleLine(const String &line, const String &source) {
  String pending = line;
  pending.trim();
  if (!pending.length()) return;
  int cmdId = hlkCommandFromText(pending);
  if (cmdId >= 0) {
    hlkDispatchCommand(cmdId, pending, source);
  } else {
    addLog(source + " text without command: " + pending);
  }
}

static void hlkSetBaud(uint32_t baud, const String &source) {
  if (!HLK_UART_ENABLED) {
    addLog("HLK-V20 UART disabled; baud not changed");
    return;
  }
  if (baud != 9600 && baud != 115200) {
    addLog(source + " bad HLK baud " + String(baud));
    return;
  }
  if (baud == hlkCurrentBaud) {
    addLog("HLK-V20 UART already at " + String(baud));
    return;
  }
  HLK.end();
  delay(20);
  hlkBegin(baud);
  addLog(source + " set HLK-V20 baud " + String(baud));
}

static void hlkToggleBaud(const String &source) {
  hlkSetBaud(hlkCurrentBaud == 115200 ? 9600 : 115200, source);
}

static String hlkFrameRaw() {
  String out;
  for (uint8_t i = 0; i < hlkFrameLen; ++i) {
    if (i) out += " ";
    out += hexByte(hlkFrame[i]);
  }
  return out;
}

static bool hlkTryDispatchFrame(bool force) {
  if (hlkFrameLen == 0) return false;
  uint8_t header = hlkFrame[0];
  bool complete = force || hlkFrameLen >= sizeof(hlkFrame);
  int cmdId = -1;

  if ((header == 0xAA || header == 0xA5 || header == 0xFD) && hlkFrameLen >= 2) {
    if (!complete) return false;
    uint8_t candidate = hlkFrame[hlkFrameLen - 1];
    if (candidate <= 20) cmdId = candidate;
  } else if (hlkFrameLen == 1 && hlkFrame[0] <= 20) {
    cmdId = hlkFrame[0];
  }

  if (cmdId < 0 && complete && hlkFrameLen > 0) {
    for (int i = (int)hlkFrameLen - 1; i >= 0; --i) {
      if (hlkFrame[i] <= 20) {
        cmdId = hlkFrame[i];
        break;
      }
    }
  }

  if (cmdId >= 0) {
    String raw = hlkFrameRaw();
    hlkFrameLen = 0;
    hlkDispatchCommand(cmdId, raw, "HLK-V20-frame");
    return true;
  }

  if (complete) {
    addLog("HLK-V20 unknown frame " + hlkFrameRaw());
    hlkFrameLen = 0;
    return true;
  }
  return false;
}

static void hlkHandleByte(uint8_t value) {
  hlkLastByteMs = millis();

  if (value == 0xAA || value == 0xA5 || value == 0xFD) {
    hlkFrame[0] = value;
    hlkFrameLen = 1;
    hlkLine = "";
    return;
  }
  if (hlkFrameLen > 0) {
    if (hlkFrameLen < sizeof(hlkFrame)) {
      hlkFrame[hlkFrameLen++] = value;
    }
    hlkTryDispatchFrame(false);
    return;
  }
  if (value == '\n' || value == '\r') {
    hlkHandleLine(hlkLine, "HLK-V20-text");
    hlkLine = "";
    return;
  }
  if (value >= 32 && value <= 126) {
    if (hlkLine.length() < 48) hlkLine += (char)value;
    return;
  }
  if (value <= 20) {
    hlkDispatchCommand((int)value, hexByte(value), "HLK-V20-byte");
    hlkLine = "";
    return;
  }
  static uint32_t lastIgnoredMs = 0;
  if (millis() - lastIgnoredMs > 1000) {
    addLog("HLK-V20 ignored byte " + hexByte(value));
    lastIgnoredMs = millis();
  }
}

static void hlkUpdate() {
  if (!HLK_UART_ENABLED) return;
  while (HLK.available()) {
    hlkHandleByte((uint8_t)HLK.read());
  }
  if (hlkFrameLen > 0 && millis() - hlkLastByteMs > HLK_FRAME_TIMEOUT_MS) {
    hlkTryDispatchFrame(true);
  }
  if (hlkLine.length() > 0 && millis() - hlkLastByteMs > 100) {
    String pending = hlkLine;
    hlkLine = "";
    hlkHandleLine(pending, "HLK-V20-timeout");
  }
}

// ============================================================================
// PIR (HC-SR501)
// ============================================================================
static bool readPirRaw() {
  bool level = digitalRead(PIN_PIR) == HIGH;
  return PIR_ACTIVE_HIGH ? level : !level;
}

static void pirBegin() {
  pinMode(PIN_PIR, INPUT);
  pirRawState = readPirRaw();
  pirPendingState = pirRawState;
  pirMotion = pirRawState;
  pirPendingSinceMs = millis();
  pirLastChangeMs = millis();
  if (pirMotion) pirLastMotionMs = millis();
  addLog("HC-SR501 PIR ready: OUT GPIO " + String(PIN_PIR));
}

static void pirUpdate() {
  const uint32_t now = millis();
  const bool raw = readPirRaw();
  if (raw != pirPendingState) {
    pirPendingState = raw;
    pirPendingSinceMs = now;
  }
  pirRawState = raw;
  if (pirMotion == pirPendingState || now - pirPendingSinceMs < PIR_DEBOUNCE_MS) return;
  pirMotion = pirPendingState;
  pirLastChangeMs = now;
  if (pirMotion) {
    pirLastMotionMs = now;
    addLog("PIR motion detected");
    audioStartCue(CUE_READY);
  } else {
    addLog("PIR motion cleared");
  }
  // Publish PIR change to backend.
  apiSendSensor(0.0f);  // PIR event — temperature not applicable
}

static bool pirAllowsMotion(const String &source, const String &action) {
  if (outputGateMode == 1) return true;
  if (outputGateMode == 2) {
    addLog(source + " " + action + " blocked: manual gate");
    audioStartCue(CUE_ERROR);
    return false;
  }
  if (!REQUIRE_PIR_FOR_OUTPUT) return true;
  if (pirMotion) return true;
  addLog(source + " " + action + " blocked: PIR has not detected a person");
  audioStartCue(CUE_ERROR);
  return false;
}

// ============================================================================
// Encoder ISR
// ============================================================================
static void IRAM_ATTR encoderIsr() {
  uint8_t state = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);
  encoderCount += QUAD_TABLE[(lastEncoderState << 2) | state];
  lastEncoderState = state;
}

static int32_t readEncoderCount() {
  noInterrupts();
  int32_t count = encoderCount;
  interrupts();
  return count;
}

static int32_t abs32(int32_t value) { return value < 0 ? -value : value; }

// ============================================================================
// Motor control
// ============================================================================
static void motorWriteRaw(int speed) {
  speed = constrain(speed, -MAX_DUTY, MAX_DUTY);
  if (!MOTOR_OUTPUT_ENABLED) {
    pwmWriteDuty(0);
    digitalWrite(PIN_IN1, LOW);
    digitalWrite(PIN_IN2, LOW);
    currentSpeed = 0;
    return;
  }
  if (speed > 0) {
    digitalWrite(PIN_IN1, HIGH);
    digitalWrite(PIN_IN2, LOW);
    pwmWriteDuty(speed);
  } else if (speed < 0) {
    digitalWrite(PIN_IN1, LOW);
    digitalWrite(PIN_IN2, HIGH);
    pwmWriteDuty(-speed);
  } else {
    pwmWriteDuty(0);
    digitalWrite(PIN_IN1, LOW);
    digitalWrite(PIN_IN2, LOW);
  }
  currentSpeed = speed;
}

static void cancelAngleMove(const String &reason) {
  if (angleMoveActive) addLog("Angle move canceled: " + reason);
  angleMoveActive = false;
  targetSpeed = 0;
}

static void cancelMotorSequence(const String &reason) {
  if (motorSequenceActive) addLog("Motor sequence canceled: " + reason);
  motorSequenceActive = false;
  motorSequencePhase = 0;
  motorSequencePhaseStartedMs = 0;
}

static int32_t angleRemainingCounts() {
  if (!angleMoveActive) return 0;
  return angleMoveTarget - readEncoderCount();
}

static void startAngleMove(float degrees, int32_t cpr, int maxSpeed, int sign) {
  if (!pirAllowsMotion("Motor", "angle move")) return;
  cancelMotorSequence("angle move");
  if (!MOTOR_OUTPUT_ENABLED) {
    addLog("Motor output locked; angle move ignored");
    targetSpeed = 0;
    angleMoveActive = false;
    return;
  }
  if (cpr < 1) {
    addLog("Angle move rejected: invalid counts/rev");
    return;
  }
  countsPerRev = cpr;
  angleMoveMaxSpeed = constrain(maxSpeed, 60, MAX_DUTY);
  encoderDirection = sign < 0 ? -1 : 1;
  prefs.putInt("cpr", countsPerRev);
  prefs.putInt("encsign", encoderDirection);
  prefs.putInt("aspeed", angleMoveMaxSpeed);

  int32_t deltaCounts = (int32_t)lroundf((float)countsPerRev * degrees / 360.0f);
  if (deltaCounts == 0) {
    cancelAngleMove("zero distance");
    return;
  }
  int32_t startCount = readEncoderCount();
  angleMoveTarget = startCount + encoderDirection * deltaCounts;
  angleMoveActive = true;
  angleMoveLastAbsRemaining = abs32(angleMoveTarget - startCount);
  angleMoveLastProgressMs = millis();
  addLog("Angle move " + String(degrees, 1) + " deg, target count " + String(angleMoveTarget));
}

static void motorSetTarget(int speed, const String &source) {
  if (speed != 0 && !pirAllowsMotion(source, "motor target")) return;
  cancelMotorSequence(source + " manual target");
  angleMoveActive = false;
  if (!MOTOR_OUTPUT_ENABLED) {
    targetSpeed = 0;
    motorWriteRaw(0);
    addLog(source + " ignored: motor output locked");
    return;
  }
  targetSpeed = constrain(speed, -MAX_DUTY, MAX_DUTY);
  addLog(source + " target speed " + String(targetSpeed));
}

static void startMotorForwardBackSequence(const String &source) {
  if (!pirAllowsMotion(source, "motor sequence")) return;
  if (!MOTOR_OUTPUT_ENABLED) {
    targetSpeed = 0;
    motorWriteRaw(0);
    addLog(source + " ignored: motor output locked");
    return;
  }
  angleMoveActive = false;
  motorSequenceActive = true;
  motorSequencePhase = 1;
  motorSequencePhaseStartedMs = millis();
  targetSpeed = -MOTOR_SEQUENCE_SPEED;
  motorWriteRaw(targetSpeed);
  addLog(source + " motor sequence: push 0.5s, return 0.5s");
}

static void motorSequenceUpdate() {
  if (!motorSequenceActive) return;
  uint32_t now = millis();
  if (motorSequencePhase == 1 && now - motorSequencePhaseStartedMs >= MOTOR_SEQUENCE_PUSH_MS) {
    motorSequencePhase = 2;
    motorSequencePhaseStartedMs = now;
    targetSpeed = MOTOR_SEQUENCE_SPEED;
    motorWriteRaw(targetSpeed);
    addLog("Motor sequence: return");
    return;
  }
  if (motorSequencePhase == 2 && now - motorSequencePhaseStartedMs >= MOTOR_SEQUENCE_RETURN_MS) {
    motorSequenceActive = false;
    motorSequencePhase = 0;
    motorSequencePhaseStartedMs = 0;
    targetSpeed = 0;
    motorWriteRaw(0);
    addLog("Motor sequence complete");
  }
}

static void angleMoveUpdate() {
  if (!angleMoveActive) return;
  int32_t remaining = angleMoveTarget - readEncoderCount();
  int32_t absRemaining = abs32(remaining);
  int32_t tolerance = countsPerRev / 720;
  if (tolerance < 3) tolerance = 3;
  if (absRemaining <= tolerance) {
    angleMoveActive = false;
    targetSpeed = 0;
    addLog("Angle move complete, remaining " + String(remaining) + " count(s)");
    return;
  }
  uint32_t now = millis();
  if (absRemaining < angleMoveLastAbsRemaining) {
    angleMoveLastAbsRemaining = absRemaining;
    angleMoveLastProgressMs = now;
  } else if (now - angleMoveLastProgressMs > 2000) {
    angleMoveActive = false;
    targetSpeed = 0;
    addLog("Angle move stopped: no encoder progress");
    return;
  }
  int motorDirection = (remaining > 0 ? 1 : -1) * encoderDirection;
  int speed = angleMoveMaxSpeed;
  int slowZone = countsPerRev / 12;
  if (slowZone < 20) slowZone = 20;
  if (absRemaining < slowZone) {
    speed = map(absRemaining, tolerance, slowZone, 70, angleMoveMaxSpeed);
  }
  speed = constrain(speed, 60, angleMoveMaxSpeed);
  targetSpeed = motorDirection * speed;
}

static void motorUpdate() {
  static uint32_t lastStepMs = 0;
  uint32_t now = millis();
  if (now - lastStepMs < 15 || currentSpeed == targetSpeed) return;
  int step = 4;
  if (currentSpeed < targetSpeed) {
    motorWriteRaw(min(currentSpeed + step, targetSpeed));
  } else {
    motorWriteRaw(max(currentSpeed - step, targetSpeed));
  }
  lastStepMs = now;
}

static void encoderRateUpdate() {
  static uint32_t lastReportMs = 0;
  static int32_t lastReportCount = 0;
  uint32_t now = millis();
  if (now - lastReportMs < 500) return;
  int32_t count = readEncoderCount();
  uint32_t elapsed = now - lastReportMs;
  int32_t delta = count - lastReportCount;
  encoderCps = elapsed > 0 ? delta * 1000.0f / elapsed : 0.0f;
  lastReportMs = now;
  lastReportCount = count;
}

// ============================================================================
// Servo control
// ============================================================================
static void servoWriteAngle(uint8_t index, uint8_t angle) {
  if (index >= SERVO_COUNT) return;
  angle = constrain(angle, 0, 180);
  uint16_t pulseUs = SERVO_MIN_US + ((uint32_t)(SERVO_MAX_US - SERVO_MIN_US) * angle) / 180UL;
  servoWritePulseUs(index, pulseUs);
  servoCurrentDeg[index] = angle;
}

static void servoWriteHome(uint8_t index) {
  if (index >= SERVO_COUNT) return;
  servoWriteAngle(index, SERVO_HOME_DEG[index]);
  servoActive[index] = false;
  servoReturnAtMs[index] = 0;
}

static void servoDispense(uint8_t index, uint32_t holdMs, const String &source) {
  if (index >= SERVO_COUNT) {
    addLog(source + " bad servo index " + String((int)index));
    return;
  }
  if (!pirAllowsMotion(source, "servo " + String(index + 1) + " push")) return;
  if (holdMs < 1) holdMs = 1;
  else if (holdMs > MAX_SERVO_HOLD_MS) holdMs = MAX_SERVO_HOLD_MS;
  servoWriteAngle(index, SERVO_PUSH_DEG[index]);
  servoActive[index] = true;
  servoReturnAtMs[index] = millis() + holdMs;
  addLog(source + " servo " + String(index + 1) + " push " + String(SERVO_PUSH_DEG[index]) + " deg for " + String(holdMs) + " ms");

  // Publish dispense_result to backend.
  char slotBuf[64];
  snprintf(slotBuf, sizeof(slotBuf), "servo=%d,state=pushed", (int)index + 1);
  apiSendDispenseResult(true, "", (int)index + 1, String(slotBuf));
}

static void servoAllHome() {
  for (uint8_t i = 0; i < SERVO_COUNT; ++i) servoWriteHome(i);
  addLog("All servos home");
}

static void servoUpdate() {
  uint32_t now = millis();
  for (uint8_t i = 0; i < SERVO_COUNT; ++i) {
    if (servoActive[i] && servoReturnAtMs[i] != 0 && (int32_t)(now - servoReturnAtMs[i]) >= 0) {
      servoWriteHome(i);
      addLog("Servo " + String(i + 1) + " home");
    }
  }
}

// ============================================================================
// Unified command dispatcher (used by HLK-V20, web, serial)
// ============================================================================
static void handleCommandId(int cmdId, const String &source) {
  lastVoiceCommand = cmdId;
  lastVoiceMs = millis();
  if (lastVoiceRaw.length() == 0) lastVoiceRaw = hexByte((uint8_t)cmdId);
  addLog(source + " command " + String(cmdId));

  switch (cmdId) {
    case 0: {
      cancelMotorSequence(source + " stop");
      targetSpeed = 0;
      angleMoveActive = false;
      motorWriteRaw(0);
      servoAllHome();
      audioStartCue(CUE_STOP);
      break;
    }
    case 1:
      startMotorForwardBackSequence(source);
      audioStartCue(CUE_VOICE);
      break;
    case 2: case 3: case 4:
      servoDispense((uint8_t)(cmdId - 1), DEFAULT_SERVO_HOLD_MS, source);
      audioStartCue(CUE_VOICE);
      break;
    case 5:
      startAngleMove(90.0f, countsPerRev, angleMoveMaxSpeed, encoderDirection);
      audioStartCue(CUE_VOICE);
      break;
    case 6:
      startAngleMove(-90.0f, countsPerRev, angleMoveMaxSpeed, encoderDirection);
      audioStartCue(CUE_VOICE);
      break;
    case 7: {
      cancelAngleMove(source + " zero");
      noInterrupts();
      encoderCount = 0;
      interrupts();
      addLog("Encoder zeroed by " + source);
      audioStartCue(CUE_OK);
      break;
    }
    case 8:
      servoAllHome();
      audioStartCue(CUE_OK);
      break;
    default:
      addLog(source + " unknown command " + String(cmdId));
      audioStartCue(CUE_ERROR);
      break;
  }
}

// ============================================================================
// WiFi
// ============================================================================
static void startStationFromPrefs(bool immediate) {
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  if (ssid.length() == 0 && strlen(DEFAULT_STA_SSID) > 0) {
    ssid = DEFAULT_STA_SSID;
    pass = DEFAULT_STA_PASS;
  }
  if (ssid.length() == 0) return;
  if (!immediate && millis() - lastStaRetryMs < 30000) return;
  WiFi.begin(ssid.c_str(), pass.c_str());
  staConnecting = true;
  staConnectStartedMs = millis();
  lastStaRetryMs = millis();
  addLog("WiFi connecting to " + ssid);
}

static void wifiUpdate() {
  wl_status_t status = WiFi.status();
  if (status == WL_CONNECTED) {
    if (!staHadConnection) {
      addLog("WiFi connected, IP " + WiFi.localIP().toString());
      staHadConnection = true;
    }
    staConnecting = false;
    return;
  }
  if (staHadConnection) {
    addLog("WiFi disconnected");
    staHadConnection = false;
  }
  if (staConnecting && millis() - staConnectStartedMs > 12000) {
    addLog("WiFi connect timeout");
    staConnecting = false;
  }
  if (!staConnecting && (prefs.getString("ssid", "").length() > 0 || strlen(DEFAULT_STA_SSID) > 0)) {
    startStationFromPrefs(false);
  }
}

// ============================================================================
// MQTT (PubSubClient) — legacy, commented out by default.
// Replaced by Backend HTTP API (see above). Kept here for reference.
// To re-enable, uncomment PubSubClient.h include and MQTT state globals
// and restore the mqttReconnect/mqttUpdate/mqttDispatchCommand code below.
// ============================================================================
// ============================================================================
// Backend HTTP API
// ============================================================================

// apiPostJson POSTs a JSON body to https://<apiBaseUrl>/api/device/<path>
// with the X-Device-Token header. Returns the HTTP response code (negative
// on connection error).
static int apiPostJson(const char *path, const char *jsonBody) {
  if (!apiConfigured || apiBaseUrl.length() == 0 || WiFi.status() != WL_CONNECTED) return -1;
  HTTPClient http;
  WiFiClientSecure secureClient;
  String url = apiBaseUrl + "/api/device/" + String(path);
  if (url.startsWith("https://")) {
    secureClient.setInsecure();
    secureClient.setHandshakeTimeout(30);
    http.begin(secureClient, url);
  } else {
    http.begin(url);
  }
  http.setReuse(false);
  http.useHTTP10(true);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Token", apiToken);
  http.setConnectTimeout(15000);
  http.setTimeout(20000);
  int code = http.POST((uint8_t *)jsonBody, strlen(jsonBody));
  String err = code <= 0 ? http.errorToString(code) : "";
  http.end();
  if (code <= 0) {
    addLog("HTTP " + String(path) + " error " + String(code) + " " + err);
  }
  return code;
}

static void apiSendHeartbeat() {
  uint32_t now = millis();
  if (now - lastApiHeartbeatMs < 30000) return;
  lastApiHeartbeatMs = now;
  if (!apiConfigured) return;
  int rssi = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : 0;
  char buf[256];
  snprintf(buf, sizeof(buf),
           "{\"battery\":85,\"temperature\":25.0,\"slot_states\":\"ready\","
           "\"wifi_rssi\":%d,\"ip_address\":\"%s\",\"firmware\":\"wroom32-1.0\"}",
           rssi, WiFi.localIP().toString().c_str());
  int code = apiPostJson("heartbeat", buf);
  if (code > 0) addLog("HTTP heartbeat " + String(code));
}

static void apiSendStatus() {
  uint32_t now = millis();
  if (now - lastApiStatusMs < 30000) return;
  lastApiStatusMs = now;
  if (!apiConfigured) return;
  int32_t count = readEncoderCount();
  char buf[256];
  snprintf(buf, sizeof(buf),
           "{\"status\":\"online\","
           "\"speed\":%d,\"encoder\":%ld,\"cps\":%.1f,"
           "\"servo_states\":\"%d%d%d%d\",\"pir_motion\":%s}",
           currentSpeed, (long)count, encoderCps,
           servoActive[0] ? 1 : 0, servoActive[1] ? 1 : 0,
           servoActive[2] ? 1 : 0, servoActive[3] ? 1 : 0,
           pirMotion ? "true" : "false");
  int code = apiPostJson("status", buf);
  if (code > 0) addLog("HTTP status " + String(code));
}

static void apiSendSensor(float temperature) {
  if (!apiConfigured) return;
  char buf[96];
  snprintf(buf, sizeof(buf), "{\"temperature\":%.1f}", temperature);
  apiPostJson("sensor", buf);
}

static void apiSendDispenseResult(bool success, const char *error, int pkgIndex, const String &slotStates) {
  if (!apiConfigured) return;
  char buf[256];
  snprintf(buf, sizeof(buf),
           "{\"success\":%s,\"error\":\"%s\",\"package_index\":%d,\"slot_states\":\"%s\"}",
           success ? "true" : "false",
           error ? error : "",
           pkgIndex,
           slotStates.c_str());
  int code = apiPostJson("dispense-result", buf);
  if (code > 0) addLog("HTTP dispense " + String(code));
}

static void apiSendSOS(const char *reason) {
  if (!apiConfigured) return;
  char buf[128];
  snprintf(buf, sizeof(buf), "{\"reason\":\"%s\"}", reason);
  int code = apiPostJson("sos", buf);
  if (code > 0) addLog("HTTP SOS " + String(code));
}

static void apiUpdate() {
  if (!apiConfigured) return;
  if (WiFi.status() != WL_CONNECTED) return;
  apiSendHeartbeat();
  apiSendStatus();
}

// ============================================================================
// Web server
// ============================================================================
static void sendJson(const String &body) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "application/json", body);
}

static void handleRoot() {
  server.sendHeader("Cache-Control", "no-store");
  server.send_P(200, "text/html", INDEX_HTML);
}

static void handleStatus() {
  int32_t count = readEncoderCount();
  uint32_t now = millis();
  String body = "{";
  body += "\"speed\":" + String(currentSpeed) + ",";
  body += "\"target\":" + String(targetSpeed) + ",";
  body += "\"encoder\":" + String(count) + ",";
  body += "\"cps\":" + String(encoderCps, 1) + ",";
  body += "\"angle\":{";
  body += "\"active\":" + String(angleMoveActive ? "true" : "false") + ",";
  body += "\"target\":" + String(angleMoveTarget) + ",";
  body += "\"remaining\":" + String(angleMoveActive ? angleMoveTarget - count : 0) + ",";
  body += "\"cpr\":" + String(countsPerRev) + ",";
  body += "\"sign\":" + String(encoderDirection) + ",";
  body += "\"maxSpeed\":" + String(angleMoveMaxSpeed);
  body += "},";
  body += "\"sta\":{";
  body += "\"connected\":" + String(WiFi.status() == WL_CONNECTED ? "true" : "false") + ",";
  body += "\"ssid\":\"" + jsonEscape(WiFi.SSID()) + "\",";
  body += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  body += "\"rssi\":" + String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0);
  body += "},";
  body += "\"ap\":{\"ssid\":\"" + String(AP_SSID) + "\",\"ip\":\"" + WiFi.softAPIP().toString() + "\"},";
  body += "\"voice\":{";
  body += "\"command\":" + String(lastVoiceCommand) + ",";
  body += "\"raw\":\"" + jsonEscape(lastVoiceRaw) + "\",";
  body += "\"ageMs\":" + String(lastVoiceMs == 0 ? 0 : millis() - lastVoiceMs) + ",";
  body += "\"baud\":" + String(hlkCurrentBaud) + ",";
  body += "\"gpio\":[";
  for (uint8_t i = 0; i < HLK_GPIO_COUNT; ++i) {
    if (i) body += ",";
    body += "{";
    body += "\"name\":\"" + jsonEscape(HLK_GPIO_NAMES[i]) + "\",";
    body += "\"pin\":" + String(HLK_GPIO_PINS[i]) + ",";
    body += "\"active\":" + String(hlkReadGpio(i) ? "true" : "false") + ",";
    body += "\"target\":\"";
    if ((int8_t)i == HLK_GPIO_MOTOR_INDEX) {
      body += "motor";
    } else {
      body += "servo " + String(HLK_GPIO_SERVO_INDEXES[i] + 1);
    }
    body += "\"";
    body += "}";
  }
  body += "]";
  body += "},";
  body += "\"audio\":{";
  body += "\"ready\":" + String(audioReady ? "true" : "false") + ",";
  body += "\"active\":" + String(audioActive ? "true" : "false");
  body += "},";
  body += "\"pir\":{";
  body += "\"pin\":" + String(PIN_PIR) + ",";
  body += "\"raw\":" + String(pirRawState ? "true" : "false") + ",";
  body += "\"motion\":" + String(pirMotion ? "true" : "false") + ",";
  body += "\"lastMotionMs\":" + String(pirLastMotionMs == 0 ? 0 : millis() - pirLastMotionMs) + ",";
  body += "\"lastChangeMs\":" + String(pirLastChangeMs == 0 ? 0 : millis() - pirLastChangeMs);
  body += "},";
  body += "\"outputGate\":{";
  body += "\"mode\":\"";
  body += outputGateMode == 1 ? "allow" : (outputGateMode == 2 ? "block" : "auto");
  body += "\",\"label\":\"";
  body += outputGateMode == 1 ? "Manual allow" : (outputGateMode == 2 ? "Manual block" : (pirMotion ? "Auto: PIR allow" : "Auto: PIR block"));
  body += "\"";
  body += "},";
  body += "\"api\":{";
  body += "\"configured\":" + String(apiConfigured ? "true" : "false") + ",";
  body += "\"baseUrl\":\"" + jsonEscape(apiBaseUrl) + "\",";
  body += "\"deviceId\":\"" + jsonEscape(apiDeviceId) + "\",";
  body += "\"tokenConfigured\":" + String(apiToken.length() > 0 ? "true" : "false");
  body += "},";
  body += "\"uptimeSec\":" + String((now - bootMillis) / 1000) + ",";
  body += "\"logs\":" + logsJson();
  body += "}";
  sendJson(body);
}

static void handleScan() {
  addLog("WiFi scan started");
  int n = WiFi.scanNetworks(false, true);
  String body = "{\"networks\":[";
  for (int i = 0; i < n; ++i) {
    if (i) body += ",";
    body += "{";
    body += "\"ssid\":\"" + jsonEscape(WiFi.SSID(i)) + "\",";
    body += "\"rssi\":" + String(WiFi.RSSI(i)) + ",";
    body += "\"enc\":\"" + authName(WiFi.encryptionType(i)) + "\",";
    body += "\"channel\":" + String(WiFi.channel(i));
    body += "}";
  }
  body += "]}";
  WiFi.scanDelete();
  addLog("WiFi scan found " + String(n) + " network(s)");
  sendJson(body);
}

static void handleWifiSave() {
  if (!server.hasArg("ssid")) {
    server.send(400, "application/json", "{\"error\":\"missing ssid\"}");
    return;
  }
  String ssid = server.arg("ssid");
  String pass = server.hasArg("pass") ? server.arg("pass") : "";
  ssid.trim();
  if (ssid.length() == 0) {
    server.send(400, "application/json", "{\"error\":\"empty ssid\"}");
    return;
  }
  prefs.putString("ssid", ssid);
  prefs.putString("pass", pass);
  WiFi.disconnect(false, false);
  delay(100);
  startStationFromPrefs(true);
  sendJson("{\"ok\":true}");
}

static void handleWifiClear() {
  prefs.remove("ssid");
  prefs.remove("pass");
  WiFi.disconnect(false, false);
  staConnecting = false;
  staHadConnection = false;
  addLog("WiFi credentials cleared");
  sendJson("{\"ok\":true}");
}

static void handleMqttSave() {
  // Deprecated — handled by handleApiSave instead.
  server.send(410, "application/json", "{\"error\":\"MQTT deprecated; use /api/api-config\"}");
}

static void handleMqttClear() {
  // Deprecated alias for handleApiClear (inlined here to avoid forward-decl issues).
  prefs.remove("api_url");
  prefs.remove("api_device_id");
  prefs.remove("api_token");
  apiBaseUrl   = "";
  apiDeviceId = "";
  apiToken     = "";
  apiConfigured = false;
  addLog("API config cleared");
  sendJson("{\"ok\":true}");
}

// ---- API config handlers (replace MQTT config) ----

static void handleApiSave() {
  String url  = server.hasArg("url")   ? server.arg("url")   : "";
  String id   = server.hasArg("id")    ? server.arg("id")    : "";
  String tok  = server.hasArg("token") ? server.arg("token") : "";
  url.trim();
  id.trim();
  tok.trim();

  if (url.length() == 0 || id.length() == 0 || tok.length() == 0) {
    server.send(400, "application/json", "{\"error\":\"url, device id, and token are required\"}");
    return;
  }
  // Strip trailing slash
  if (url.endsWith("/")) url.remove(url.length() - 1);

  prefs.putString("api_url",  url);
  prefs.putString("api_device_id", id);
  prefs.putString("api_token", tok);

  apiBaseUrl  = url;
  apiDeviceId = id;   // reuse global device-id variable
  apiToken     = tok;
  apiConfigured = (apiBaseUrl.length() > 0 && apiToken.length() > 0);
  lastApiHeartbeatMs = 0;
  lastApiStatusMs    = 0;

  addLog("API configured: " + apiBaseUrl + " id=" + apiDeviceId);
  // Send an immediate heartbeat so the backend marks the device online
  lastApiHeartbeatMs = 30000;  // force expiry → next apiUpdate sends immediately
  apiUpdate();
  sendJson("{\"ok\":true}");
}

static void handleApiClear() {
  prefs.remove("api_url");
  prefs.remove("api_device_id");
  prefs.remove("api_token");
  apiBaseUrl   = "";
  apiDeviceId = "";
  apiToken     = "";
  apiConfigured = false;
  addLog("API config cleared");
  sendJson("{\"ok\":true}");
}

static void handleMotor() {
  if (!server.hasArg("speed")) {
    server.send(400, "application/json", "{\"error\":\"missing speed\"}");
    return;
  }
  motorSetTarget(server.arg("speed").toInt(), "Web");
  sendJson("{\"ok\":true}");
}

static void handleAngle() {
  if (!server.hasArg("degrees")) {
    server.send(400, "application/json", "{\"error\":\"missing degrees\"}");
    return;
  }
  float degrees = server.arg("degrees").toFloat();
  int32_t cpr = server.hasArg("cpr") ? server.arg("cpr").toInt() : countsPerRev;
  int maxSpeed = server.hasArg("speed") ? server.arg("speed").toInt() : angleMoveMaxSpeed;
  int sign = server.hasArg("sign") ? server.arg("sign").toInt() : encoderDirection;
  if (cpr < 1 || cpr > 200000) {
    server.send(400, "application/json", "{\"error\":\"bad counts per revolution\"}");
    return;
  }
  if (degrees < -3600.0f || degrees > 3600.0f) {
    server.send(400, "application/json", "{\"error\":\"bad degrees\"}");
    return;
  }
  startAngleMove(degrees, cpr, maxSpeed, sign);
  sendJson("{\"ok\":true}");
}

static void handleZero() {
  cancelAngleMove("encoder zero");
  noInterrupts();
  encoderCount = 0;
  interrupts();
  addLog("Encoder zeroed");
  sendJson("{\"ok\":true}");
}

static void handleServoPush() {
  if (!server.hasArg("index")) {
    server.send(400, "application/json", "{\"error\":\"missing index\"}");
    return;
  }
  int idx = server.arg("index").toInt() - 1;
  if (idx < 0 || idx >= (int)SERVO_COUNT) {
    server.send(400, "application/json", "{\"error\":\"bad servo index\"}");
    return;
  }
  int holdMs = server.hasArg("holdMs") ? server.arg("holdMs").toInt() : DEFAULT_SERVO_HOLD_MS;
  servoDispense((uint8_t)idx, (uint32_t)holdMs, "Web");
  sendJson("{\"ok\":true}");
}

static void handleServoAngle() {
  if (!server.hasArg("index") || !server.hasArg("angle")) {
    server.send(400, "application/json", "{\"error\":\"missing index or angle\"}");
    return;
  }
  int idx = server.arg("index").toInt() - 1;
  int angle = server.arg("angle").toInt();
  if (idx < 0 || idx >= (int)SERVO_COUNT) {
    server.send(400, "application/json", "{\"error\":\"bad servo index\"}");
    return;
  }
  if (angle < 0 || angle > 180) {
    server.send(400, "application/json", "{\"error\":\"bad angle\"}");
    return;
  }
  if (!pirAllowsMotion("Web", "servo " + String(idx + 1) + " angle")) {
    sendJson("{\"ok\":false,\"error\":\"pir_clear\"}");
    return;
  }
  servoWriteAngle((uint8_t)idx, (uint8_t)angle);
  servoActive[idx] = false;
  servoReturnAtMs[idx] = 0;
  addLog("Web servo " + String(idx + 1) + " angle " + String(angle));
  sendJson("{\"ok\":true}");
}

static void handleServoHome() {
  if (!server.hasArg("index")) {
    server.send(400, "application/json", "{\"error\":\"missing index\"}");
    return;
  }
  String idx = server.arg("index");
  if (idx == "all") {
    servoAllHome();
  } else {
    int i = idx.toInt() - 1;
    if (i < 0 || i >= (int)SERVO_COUNT) {
      server.send(400, "application/json", "{\"error\":\"bad servo index\"}");
      return;
    }
    servoWriteHome((uint8_t)i);
  }
  sendJson("{\"ok\":true}");
}

static void handleOutputGate() {
  if (!server.hasArg("mode")) {
    server.send(400, "application/json", "{\"error\":\"missing mode\"}");
    return;
  }
  String mode = server.arg("mode");
  mode.trim();
  if (mode == "allow") {
    outputGateMode = 1;
  } else if (mode == "block") {
    outputGateMode = 2;
  } else {
    outputGateMode = 0;
  }
  prefs.putUChar("gate", outputGateMode);
  addLog("Output gate set to " + (outputGateMode == 1 ? String("manual allow") : (outputGateMode == 2 ? String("manual block") : String("auto PIR"))));
  sendJson("{\"ok\":true}");
}

static void handleVoiceTest() {
  if (!server.hasArg("cmd")) {
    server.send(400, "application/json", "{\"error\":\"missing cmd\"}");
    return;
  }
  int cmdId = server.arg("cmd").toInt();
  handleCommandId(cmdId, "Web");
  sendJson("{\"ok\":true}");
}

static void handleAudioBeep() {
  audioStartCue(CUE_READY);
  addLog("I2S beep test");
  sendJson("{\"ok\":true}");
}

static void handleNotFound() {
  server.send(404, "text/plain", "Not found");
}

static void startWebServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/scan", HTTP_GET, handleScan);
  server.on("/api/wifi", HTTP_POST, handleWifiSave);
  server.on("/api/wifi/clear", HTTP_POST, handleWifiClear);
  server.on("/api/mqtt", HTTP_POST, handleMqttSave);  // deprecated, stub
  server.on("/api/mqtt/clear", HTTP_POST, handleApiClear);
  server.on("/api/api-config", HTTP_POST, handleApiSave);
  server.on("/api/api-config/clear", HTTP_POST, handleApiClear);
  server.on("/api/motor", HTTP_POST, handleMotor);
  server.on("/api/angle", HTTP_POST, handleAngle);
  server.on("/api/zero", HTTP_POST, handleZero);
  server.on("/api/servo/push", HTTP_POST, handleServoPush);
  server.on("/api/servo/angle", HTTP_POST, handleServoAngle);
  server.on("/api/servo/home", HTTP_POST, handleServoHome);
  server.on("/api/output-gate", HTTP_POST, handleOutputGate);
  server.on("/api/voice", HTTP_POST, handleVoiceTest);
  server.on("/api/audio/beep", HTTP_POST, handleAudioBeep);
  server.onNotFound(handleNotFound);
  server.begin();
  addLog("Web server started");
}

static void startWiFi() {
  WiFi.persistent(false);
  WiFi.setSleep(false);
  WiFi.mode(WIFI_AP_STA);
  bool apOk = WiFi.softAP(AP_SSID, AP_PASS);
  if (apOk) {
    addLog("AP started, IP " + WiFi.softAPIP().toString());
  } else {
    addLog("AP start failed");
  }
  startStationFromPrefs(true);
}

// loadApiPrefs replaces loadMqttPrefs.
static void loadApiPrefs() {
  apiBaseUrl   = prefs.getString("api_url", API_DEFAULT_BASE_URL);
  apiDeviceId = prefs.getString("api_device_id", API_DEFAULT_DEVICE_ID);
  apiToken     = prefs.getString("api_token", API_DEFAULT_DEVICE_TOKEN);
  apiConfigured = (apiBaseUrl.length() > 0 && apiToken.length() > 0);
}

// ============================================================================
// Diagnostics & Serial CLI
// ============================================================================
static void printHelp() {
  Serial.println();
  Serial.println("Commands:");
  Serial.println("  -255..255   set L298N motor speed");
  Serial.println("  deg 90      rotate by encoder-calibrated degrees");
  Serial.println("  cpr 1440    set encoder counts per output revolution");
  Serial.println("  p1 650      servo 1 push then return home, p2/p3/p4 also work");
  Serial.println("  svo1 45     set servo 1 angle directly");
  Serial.println("  home        return all servos home");
  Serial.println("  voice 1..8  simulate HLK-V20 command id");
  Serial.println("  hlk 9600     switch HLK-V20 UART baud; hlk 115200 or hlk toggle");
  Serial.println("  beep        play MAX98357 I2S test tone");
  Serial.println("  s/stop      stop motor and return all servos home");
  Serial.println("  z/zero      zero encoder count");
  Serial.println("  ip          print web addresses");
  Serial.println();
}

static void printAddresses() {
  Serial.print("AP URL:  http://");
  Serial.println(WiFi.softAPIP());
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("STA URL: http://");
    Serial.println(WiFi.localIP());
  }
  if (apiConfigured) {
    Serial.print("API:     ");
    Serial.print(apiBaseUrl);
    Serial.print(" id=");
    Serial.println(apiDeviceId);
  }
}

static void handleSerial() {
  static String line;
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\r') continue;
    if (c == '\n') {
      line.trim();
      line.toLowerCase();
      if (line.length()) {
        if (line == "s" || line == "stop") {
          motorSetTarget(0, "Serial");
        } else if (line == "z" || line == "zero") {
          noInterrupts();
          encoderCount = 0;
          interrupts();
          addLog("Encoder zeroed");
        } else if (line == "ip") {
          printAddresses();
        } else if (line == "beep") {
          audioStartCue(CUE_READY);
          addLog("I2S beep test");
        } else if (line == "home") {
          servoAllHome();
        } else if (line.startsWith("voice ")) {
          handleCommandId(line.substring(6).toInt(), "Serial");
        } else if (line.startsWith("hlk ")) {
          String baud = line.substring(4);
          baud.trim();
          if (baud == "toggle") {
            hlkToggleBaud("Serial");
          } else {
            hlkSetBaud((uint32_t)baud.toInt(), "Serial");
          }
        } else if (line.startsWith("deg ")) {
          startAngleMove(line.substring(4).toFloat(), countsPerRev, angleMoveMaxSpeed, encoderDirection);
        } else if (line.startsWith("cpr ")) {
          int32_t cpr = line.substring(4).toInt();
          if (cpr > 0 && cpr <= 200000) {
            countsPerRev = cpr;
            prefs.putInt("cpr", countsPerRev);
            addLog("Counts/rev set to " + String(countsPerRev));
          } else {
            addLog("Invalid counts/rev");
          }
        } else if (line.startsWith("svo") || line.startsWith("servo")) {
          uint8_t offset = line.startsWith("svo") ? 3 : 5;
          uint8_t index = (uint8_t)(line.substring(offset, offset + 1).toInt() - 1);
          bool found = false;
          int angle = extractFirstInt(line.substring(offset + 1), found);
          if (index < SERVO_COUNT && found && angle >= 0 && angle <= 180) {
            if (pirAllowsMotion("Serial", "servo " + String(index + 1) + " angle")) {
              servoWriteAngle(index, (uint8_t)angle);
              servoActive[index] = false;
              servoReturnAtMs[index] = 0;
              addLog("Serial servo " + String(index + 1) + " angle " + String(angle));
            }
          }
        } else if (line.startsWith("p")) {
          uint8_t index = (uint8_t)(line.substring(1, 2).toInt() - 1);
          uint32_t duration = DEFAULT_SERVO_HOLD_MS;
          bool found = false;
          int parsed = extractFirstInt(line.substring(2), found);
          if (found && parsed > 0) duration = (uint32_t)parsed;
          servoDispense(index, duration, "Serial");
        } else {
          bool found = false;
          int v = extractFirstInt(line, found);
          if (found) {
            if (line.startsWith("cmd")) {
              handleCommandId(v, "Serial");
            } else {
              motorSetTarget(v, "Serial");
            }
          }
        }
      }
      line = "";
    } else if (line.length() < 64) {
      line += c;
    }
  }
}

// ============================================================================
// setup / loop
// ============================================================================
void setup() {
  bootMillis = millis();
  Serial.begin(115200);
  delay(500);

  pinMode(PIN_IN1, OUTPUT);
  pinMode(PIN_IN2, OUTPUT);
  pinMode(PIN_ENC_A, INPUT_PULLUP);
  pinMode(PIN_ENC_B, INPUT_PULLUP);

  lastEncoderState = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), encoderIsr, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_B), encoderIsr, CHANGE);

  pwmBegin();
  motorWriteRaw(0);

  prefs.begin("med", false);
  countsPerRev = prefs.getInt("cpr", countsPerRev);
  if (countsPerRev < 1) countsPerRev = 1440;
  encoderDirection = prefs.getInt("encsign", encoderDirection) < 0 ? -1 : 1;
  angleMoveMaxSpeed = constrain(prefs.getInt("aspeed", angleMoveMaxSpeed), 60, MAX_DUTY);
  outputGateMode = prefs.getUChar("gate", 0);
  if (outputGateMode > 2) outputGateMode = 0;
  loadApiPrefs();

  servoPwmBegin();
  servoAllHome();
  audioBegin();
  pirBegin();
  hlkBegin();
  hlkGpioBegin();
  audioStartCue(CUE_READY);

  Serial.println("ESP32-WROOM-32 Medication Dispenser");
  if (!MOTOR_OUTPUT_ENABLED) Serial.println("Motor output is locked in firmware.");
  printHelp();

  startWiFi();
  startWebServer();
  printAddresses();
}

// loop() — same structure, just calls apiUpdate() instead of mqttUpdate()
void loop() {
  audioUpdate();
  pirUpdate();
  hlkUpdate();
  hlkGpioUpdate();
  server.handleClient();
  wifiUpdate();
  motorSequenceUpdate();
  angleMoveUpdate();
  motorUpdate();
  encoderRateUpdate();
  servoUpdate();
  apiUpdate();
  handleSerial();
}
