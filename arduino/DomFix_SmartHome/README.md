# DomFix Smart Home - ESP32 Hardware Guide V2

This directory contains the firmware for the ESP32 that connects directly to the DomFix Flutter application using **Firebase Realtime Database** and a **Local HTTP WebServer** for ultra-low-latency control.

## Architecture

```
Flutter App ──→ Local HTTP (http://<ESP32_IP>/control)  ──→  ESP32  ──→  Hardware
     │                                                         │
     └──→ Firebase RTDB (Cloud Fallback) ──────────────────────┘
```

The system supports **dual-mode communication**:
- **Local Mode**: Direct HTTP to ESP32 on same WiFi network (<50ms latency)
- **Cloud Mode**: Via Firebase RTDB when not on the same network

## Required Hardware
* 1x ESP32 Development Board
* 1x DHT11 Temperature & Humidity Sensor
* 1x LDR (Photoresistor) + 10k Resistor
* 1x TTP223 Touch Sensor
* 1x SG90 Servo Motor (for Smart Door)
* 1x DC Motor + L298N Motor Driver or Transistor (for Smart Fan)
* 1x LED + 220 Ohm Resistor (for Smart Light)
* Breadboard and Jumper Wires

## Pin Mapping & Wiring Guide

### 1. Smart Light (LED)
* **ESP32 Pin:** `GPIO 2`
* **Wiring:** ESP32 GPIO 2 -> 220 Ohm Resistor -> LED Anode (Long Leg). LED Cathode (Short Leg) -> GND.

### 2. Smart Fan (DC Motor)
* **ESP32 Pin:** `GPIO 4`
* **Wiring:** Do NOT connect the DC motor directly to the ESP32! Use an L298N motor driver or an NPN Transistor (e.g., 2N2222).
  * If using Transistor: ESP32 GPIO 4 -> 1k Resistor -> Base. Emitter -> GND. Collector -> Motor -> 5V.

### 3. Smart Door (Servo Motor)
* **ESP32 Pin:** `GPIO 18`
* **Wiring:** 
  * Orange/Signal Wire -> ESP32 GPIO 18
  * Red/VCC Wire -> 5V (VIN on ESP32 if powered by USB)
  * Brown/GND Wire -> GND

### 4. Climate Sensor (DHT11)
* **ESP32 Pin:** `GPIO 15`
* **Wiring:** 
  * VCC -> 3.3V
  * DATA -> ESP32 GPIO 15 (add a 10k pull-up resistor between DATA and VCC if your module doesn't have one)
  * GND -> GND

### 5. Light Sensor (LDR)
* **ESP32 Pin:** `GPIO 34` (Analog Input)
* **Wiring (Voltage Divider):**
  * 3.3V -> LDR -> GPIO 34
  * GPIO 34 -> 10k Resistor -> GND

### 6. Touch Switch (TTP223)
* **ESP32 Pin:** `GPIO 13`
* **Wiring:**
  * VCC -> 3.3V
  * I/O -> ESP32 GPIO 13
  * GND -> GND

## Library Dependencies (Arduino IDE)

To compile `DomFix_SmartHome.ino`, you must install the following libraries via the Library Manager:
1. **Firebase ESP32 Client** by mobizt (Search for `Firebase ESP32 Client`)
2. **DHT sensor library** by Adafruit
3. **ESP32Servo** by Kevin Harrington
4. **ArduinoJson** by Benoit Blanchon (v7+)
5. **WebServer** (included with ESP32 Arduino Core - no install needed)

## Setup Instructions

1. Open `DomFix_SmartHome.ino` in the Arduino IDE.
2. Update the `WIFI_SSID` and `WIFI_PASSWORD`.
3. Go to Firebase Console -> Project Settings -> General -> Web API Key. Copy this into `API_KEY`.
4. Go to Firebase Console -> Realtime Database. Copy the URL (e.g., `https://your-project.firebaseio.com/`) into `DATABASE_URL`.
5. Ensure `USER_EMAIL` and `USER_PASSWORD` correspond to an account created in your DomFix Flutter app.
6. Compile and upload to the ESP32.
7. Open the Serial Monitor at 115200 baud to verify the connection.

## Local WebServer Endpoints

Once the ESP32 boots and connects to WiFi, it starts a WebServer on port 80:

| Endpoint    | Method  | Description                          |
|-------------|---------|--------------------------------------|
| `/`         | GET     | HTML dashboard showing device states |
| `/control`  | POST    | Control a device via JSON body       |
| `/status`   | GET     | JSON snapshot of all device states   |

### POST `/control` - Body Format

```json
{
  "device": "ESP32_LED",
  "action": "toggle",
  "value": true,
  "numValue": 0.75
}
```

**Device IDs:** `ESP32_LED`, `ESP32_FAN`, `ESP32_SERVO`

### GET `/status` - Response Format

```json
{
  "led": { "isOn": true, "brightness": 0.8 },
  "fan": { "isOn": false, "speed": 0.5 },
  "door": { "isOn": false },
  "temperature": 24.5,
  "humidity": 45.2,
  "ldr": 1234,
  "uptime": 3600,
  "wifi_rssi": -45,
  "ip": "192.168.1.100"
}
```

## V2 Features

- **Local HTTP Control**: Direct HTTP POST to ESP32 for sub-50ms response
- **Auto IP Reporting**: ESP32 writes its IP to Firebase so the Flutter app can discover it
- **Non-Blocking Loop**: All operations use `millis()` — no `delay()` in the main loop
- **CORS Support**: WebServer accepts cross-origin requests
- **Heartbeat**: Sends uptime, RSSI, and free heap to Firebase every 30s
- **Graceful WiFi Reconnection**: Automatically reconnects without blocking
