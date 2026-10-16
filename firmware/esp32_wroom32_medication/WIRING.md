# ESP32-WROOM-32 + L298N + HLK-V20 + 4 Servos + HC-SR501 + MAX98357 wiring

This sketch targets an **ESP32-WROOM-32** development board (not ESP32-S3).

Modules supported:

- One L298N-driven encoder motor.
- One HLK-V20 offline voice module over GPIO trigger outputs, with optional UART.
- Four small SG90-class servos for dispensing actions.
- One HC-SR501 PIR motion sensor.
- One MAX98357 I2S amplifier for prompt tones.
- WiFi AP + STA with Web configuration page.
- MQTT client (PubSubClient) for backend integration.

Default WiFi STA:

| Field | Value |
| --- | --- |
| SSID | Configure through the local setup page |
| Password | Configure through the local setup page; do not store it in source code |

Sketch path:

`firmware/esp32_wroom32_medication/esp32_wroom32_medication.ino`

Arduino libraries required:

- `PubSubClient` by Nick O'Leary — install via Arduino Library Manager.
- All others (WebServer, WiFi, Preferences, driver/i2s.h) are built-in.

## WROOM-32 important note: GPIO6-11 are internal flash

Never wire anything to GPIO6, 7, 8, 9, 10, or 11. Using them will corrupt
the flash and the board will not boot.

## ESP32-WROOM-32 pin map

| Function | WROOM-32 GPIO | Notes |
| --- | --- | --- |
| L298N ENA (PWM) | GPIO2 | |
| L298N IN1 | GPIO4 | |
| L298N IN2 | GPIO15 | Strapping pin; safe for output after boot |
| Encoder A | GPIO32 | Input-only pin, ideal for encoder ISR |
| Encoder B | GPIO33 | Input-only pin |
| HLK-V20 command output | GPIO34 | Rising edge triggers motor push 0.5 s, return 0.5 s |
| HLK-V20 command output | GPIO5 | Rising edge triggers servo GPIO27 push |
| HLK-V20 command output | GPIO18 | Rising edge triggers servo GPIO12 reverse push |
| HLK-V20 command output | GPIO19 | Rising edge triggers servo GPIO21 push |
| HLK-V20 TX → ESP RX | GPIO16 | Serial1 RX (explicit, not default 9/10) |
| HLK-V20 RX ← ESP TX | GPIO17 | Serial1 TX (explicit, not default 9/10) |
| HC-SR501 OUT | GPIO13 | |
| Servo 1 signal | GPIO14 | |
| Servo 2 signal | GPIO27 | |
| Servo 3 signal | GPIO12 | Strapping pin; output-only, safe after boot |
| Servo 4 signal | GPIO21 | |
| MAX98357 BCLK | GPIO26 | WROOM-32 I2S0 fixed pin |
| MAX98357 LRCLK | GPIO25 | WROOM-32 I2S0 fixed pin |
| MAX98357 DIN | GPIO22 | WROOM-32 I2S0 fixed pin |
| MAX98357 SD (enable) | GPIO23 | Output; controls amplifier shutdown |

## Power wiring

All low-voltage control boards **must share ground**:

| Module | Power notes |
| --- | --- |
| ESP32-WROOM-32 | USB or stable 5V input (via CP2102/CH340 or USB-C) |
| L298N logic | 5V and GND; share GND with ESP32 |
| L298N motor supply | External motor supply, sized for the encoder motor |
| Encoder | 3.3V preferred (outputs connect directly to ESP32 GPIO32/33) |
| HLK-V20 | Use the voltage printed on your module silk screen / manual |
| HC-SR501 | 5V (VCC to 5V, GND to common GND) |
| Servos | **External 5V supply with enough current**, not ESP32 3.3V |
| MAX98357 | 5V VIN; GND tied to common ground |

Important:

- Servo power supply GND **must** connect to ESP32 GND.
- Do not power four SG90 servos from the ESP32 5V pin. Each SG90 draws 500 mA+
  during movement; use a dedicated 5V/2A+ supply.
- WROOM-32 GPIO is **3.3V logic and is NOT 5V tolerant**. If any HLK-V20
  GPIO output or TX pin outputs 5V, add a level shifter or resistor divider
  before it enters the ESP32.

## L298N wiring

| ESP32-WROOM-32 | L298N |
| --- | --- |
| GPIO2 | ENA |
| GPIO4 | IN1 |
| GPIO15 | IN2 |
| GND | GND |

Remove the L298N ENA jumper if you want PWM speed control from GPIO2.

## Encoder wiring

| Encoder | ESP32-WROOM-32 |
| --- | --- |
| A | GPIO32 |
| B | GPIO33 |
| VCC | 3.3V preferred |
| GND | GND |

The code uses `INPUT_PULLUP` on both encoder pins.

## HLK-V20 wiring

Current voice-module configuration uses GPIO outputs set HIGH when phrases are
recognized. Wire these first:

| HLK-V20 output | ESP32-WROOM-32 input | Servo signal | Action |
| --- | --- | --- | --- |
| Command output | GPIO34 | - | Motor push 0.5 s -> return 0.5 s -> stop |
| Command output | GPIO5 | GPIO27 | Push: 0 deg -> 90 deg -> 0 deg |
| Command output | GPIO18 | GPIO12 | Reverse push: 90 deg -> 0 deg -> 90 deg |
| Command output | GPIO19 | GPIO21 | Push: 0 deg -> 90 deg -> 0 deg |
| GND | GND | - | Common ground |
| VCC | Module-rated power | - | Use the module's rated supply |

The ESP32 triggers once on each rising edge after debounce. If GPIO34 stays
HIGH, the motor still runs only the fixed push 0.5 s -> return 0.5 s sequence.
If any input stays HIGH, the firmware ignores the held level until it goes LOW and rises again.
An already-HIGH input at boot is recorded as the current state and does not run
a servo action. In the HLK-V20 configuration tool, prefer a short HIGH pulse
followed by LOW for each command so repeated voice commands can be recognized
cleanly. The web status page shows each voice GPIO as `GPIO34:0/1`, etc. so
you can confirm whether the ESP32 is seeing the module output.

Optional UART wiring is still supported by the firmware:

| HLK-V20 UART | ESP32-WROOM-32 |
| --- | --- |
| TXD | GPIO16 (ESP32 RX) |
| RXD | GPIO17 (ESP32 TX) |
| GND | GND |

The UART parser reads command ids (0-8) from the module when UART is wired.
The default UART baud rate is `115200`. If your HLK-V20 project is configured
for `9600`, open the serial monitor and send `hlk 9600`; send `hlk 115200` to
switch back. The current baud rate is shown on the web Voice card.

| Command ID | Action |
| --- | --- |
| 0 | Emergency stop (motor + all servos home) |
| 1 | Motor push 0.5 s, return 0.5 s, stop |
| 2 | Servo 2 push |
| 3 | Servo 3 push |
| 4 | Servo 4 push |
| 5 | Servo GPIO27 push when received from HLK-V20 UART |
| 6 | Motor -90° angle move |
| 7 | Zero encoder |
| 8 | Return all servos home |

The HLK-V20 UART parser accepts common framed bytes starting with `0xAA`,
`0xA5`, or `0xFD`, raw byte command ids, and ASCII text commands/numeric
strings such as `"1"`, `"stop"`, and `"home"`.

## HC-SR501 PIR wiring

| HC-SR501 | ESP32-WROOM-32 |
| --- | --- |
| VCC | 5V |
| GND | GND |
| OUT | GPIO13 |

`PIR_ACTIVE_HIGH = true` (default HC-SR501 behavior: OUT goes HIGH when motion
is detected). The code applies 120 ms debounce.

PIR changes are published to MQTT topic:
`blind_medication/devices/<id>/sensor`

## Servo wiring

Most small servos have three wires:

| Servo wire | Connect to |
| --- | --- |
| Brown/black (GND) | External 5V supply GND **and** ESP32 GND |
| Red (VCC) | External 5V servo supply positive |
| Orange/yellow (signal) | ESP32 servo signal GPIO |

| Servo | Signal GPIO |
| --- | --- |
| Servo 1 | GPIO14 |
| Servo 2 | GPIO27 |
| Servo 3 | GPIO12 |
| Servo 4 | GPIO21 |

Default angles in code:

| Servo signal | Home | Push |
| --- | --- | --- |
| GPIO14 | 90 deg | 0 deg |
| GPIO27 | 0 deg | 90 deg |
| GPIO12 | 90 deg | 0 deg |
| GPIO21 | 0 deg | 90 deg |

Change `SERVO_HOME_DEG` and `SERVO_PUSH_DEG` in the `.ino` file if your
mechanism needs different angles. Hold time (push before return) is
configurable via the web UI or API; default is 850 ms.

## MAX98357 I2S wiring

| ESP32-WROOM-32 | MAX98357 board |
| --- | --- |
| GND | GND |
| 5V | VIN |
| GPIO26 | BCLK / BCK |
| GPIO25 | LRC / WS / LRCLK |
| GPIO22 | DIN / DATA |
| GPIO23 | SD / ENABLE |

Notes:

- WROOM-32 I2S0 pins are **fixed** to GPIO25/26/22 by hardware. You cannot
  change them. The code matches these pins exactly.
- Do not connect the speaker to ESP32 ground. The speaker connects only to the
  MAX98357 output terminals.
- If your MAX98357 board does not expose SD, leave GPIO23 unused and tie SD high
  per your board's instructions.
- GAIN can usually be left floating.

## Backend HTTP API integration

The current firmware reports to the backend over HTTP with an `X-Device-Token` header.
Configure the backend URL, device ID, and token from the local web UI at
`the device AP address shown in the firmware status page` → **Backend HTTP API**. These values are stored in NVS and
are deliberately empty in source code.

The HTTP endpoints are:

| Endpoint | Purpose |
| --- | --- |
| `POST /api/device/heartbeat` | Battery, temperature, signal, IP, and firmware metadata |
| `POST /api/device/status` | Device status and actuator state |
| `POST /api/device/sensor` | Sensor data |
| `POST /api/device/dispense-result` | Dispense result |
| `POST /api/device/sos` | Emergency notification |

Do not paste a real device token into source code, screenshots, or documentation.

## Bring-up order

1. Install `PubSubClient` library in Arduino IDE (Library Manager).
2. Select board: **esp32:esp32:esp32** (ESP32 Dev Module).
3. Flash the firmware to WROOM-32 via USB.
4. Power only ESP32-WROOM-32 and MAX98357 first.
5. Connect to WiFi AP `ESP32S3-Motor` using the AP password configured in the firmware before deployment.
6. Open `http://192.168.4.1` in a browser.
7. Press **Beep** in the Servos panel. If the speaker plays tones, MAX98357
   wiring is correct.
8. In the Servos panel, press **Push** on each servo one at a time to verify
   they move to 90° and return to 0°.
9. In the Motor Test panel, set speed to +120 and press **Set** to verify the
   L298N motor spins. Press **Stop**.
10. In the Angle Move panel, rotate +90° to verify encoder reading.
11. Wave a hand near HC-SR501 and check the PIR status card says "Detected".
12. Speak each pre-recorded HLK-V20 phrase and check the Voice card and web log
    for `HLK-V20-GPIO servo ...` or `HLK-V20 ... -> servo ...` entries. If
    there is no entry, check the Voice GPIO card first: the matching pin should
    change from `0` to `1`.
    If UART is wired and there are still no entries, try `hlk 9600` in the
    serial monitor and speak the phrase again.
13. Configure the backend URL, device ID, and device token in the **Backend HTTP API** panel, then press **Save and Connect**. Verify heartbeat requests arrive at the backend.

The device does not contain a default station WiFi password or backend token;
configure both through the setup page before connecting it to a non-isolated network.

## Serial CLI reference

Open Arduino Serial Monitor at `115200` baud:

| Command | Meaning |
| --- | --- |
| `120` | L298N motor forward speed 120 |
| `-120` | L298N motor reverse speed 120 |
| `stop` / `s` | Stop motor and return all servos home |
| `deg 90` | Rotate encoder motor by +90 degrees |
| `cpr 1440` | Set encoder counts per output revolution |
| `p1 650` | Servo 1 push for 650 ms then return home |
| `p2 650` | Servo 2 push for 650 ms then return home |
| `svo1 45` | Set servo 1 directly to 45 degrees |
| `home` | Return all servos home |
| `voice 1..8` | Simulate HLK-V20 command id |
| `hlk 9600` / `hlk 115200` | Switch HLK-V20 UART baud rate |
| `hlk toggle` | Toggle HLK-V20 UART between 115200 and 9600 |
| `beep` | Play MAX98357 I2S test tone |
| `zero` / `z` | Zero encoder count |
| `ip` | Print web and MQTT addresses |

If `deg 90` moves the wrong direction, adjust the `encoderDirection` NVS pref
via the web Angle Move panel (Normal vs Invert).

## Safety defaults

```cpp
static const bool MOTOR_OUTPUT_ENABLED = true;
static const bool HLK_UART_ENABLED = true;
```

Both are enabled because the user has all hardware wired. Set either to `false`
to disable the corresponding subsystem without removing wiring.
