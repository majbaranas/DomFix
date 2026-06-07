# 🏠 DomFix ESP32 + IoT Integration Guide

**Production-ready smart home system with real hardware control**

---

## 📋 Table of Contents

1. [System Architecture](#system-architecture)
2. [Hardware Requirements](#hardware-requirements)
3. [Firebase Setup](#firebase-setup)
4. [ESP32 Setup](#esp32-setup)
5. [Flutter App Setup](#flutter-app-setup)
6. [Testing Guide](#testing-guide)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ System Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│             │         │              │         │             │
│  ESP32      │◄────────┤   Firebase   │◄────────┤  Flutter    │
│  Hardware   │         │   Firestore  │         │  Mobile App │
│             │         │              │         │             │
└─────────────┘         └──────────────┘         └─────────────┘
      │                                                  │
      │                                                  │
   Real-Time                                        User Control
  Sync (10s)                                        (Instant)
      │                                                  │
      ▼                                                  ▼
┌─────────────────────────────────────────────────────────────┐
│  Devices: Light, Fan, Door, Temperature, Brightness         │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**User Action → App:**
1. User taps "Light ON" in Flutter app
2. App updates Firestore: `isOn: true`
3. ESP32 detects change via Firebase listener
4. ESP32 activates relay
5. 220V lamp turns ON instantly

**Sensor Data → App:**
1. ESP32 reads DHT11 temperature (every 5s)
2. ESP32 writes to Firebase: `value: 24.5`
3. Flutter app receives real-time update
4. UI displays: "24.5°C"

---

## 🔧 Hardware Requirements

### ESP32 Board
- ESP32-WROOM-32 or similar
- Built-in WiFi
- 512KB RAM minimum

### Components

| Component | Quantity | Purpose | Pin |
|-----------|----------|---------|-----|
| 2-Channel Relay Module | 1 | Control 220V devices | GPIO 25, 26 |
| Servo Motor SG90 | 1 | Door/curtain control | GPIO 27 |
| DHT11 Sensor | 1 | Temperature/Humidity | GPIO 14 |
| LDR Sensor | 1 | Light intensity | GPIO 34 (analog) |
| 220V Lamp | 1 | Living room light | Via Relay 1 |
| 12V Fan | 1 | Bedroom fan | Via Relay 2 |
| Jumper Wires | 20+ | Connections | - |
| Breadboard | 1 | Prototyping | - |
| 5V Power Supply | 1 | ESP32 & Relay power | - |

### Wiring Diagram

```
ESP32                    Relay Module
─────                    ────────────
GPIO 25  ────────────────► IN1 (Light)
GPIO 26  ────────────────► IN2 (Fan)
GND      ────────────────► GND
5V       ────────────────► VCC

ESP32                    Servo Motor
─────                    ───────────
GPIO 27  ────────────────► Signal (Orange)
5V       ────────────────► VCC (Red)
GND      ────────────────► GND (Brown)

ESP32                    DHT11
─────                    ─────
GPIO 14  ────────────────► DATA
5V       ────────────────► VCC
GND      ────────────────► GND

ESP32                    LDR
─────                    ───
GPIO 34  ────────────────► Signal
GND      ────────────────► GND (via 10kΩ)
```

---

## 🔥 Firebase Setup

### 1. Firestore Database Structure

Create this structure in Firestore:

```
smart_devices/
└── {userId}/
    └── devices/
        ├── {deviceId1}/
        │   ├── name: "Living Room Light"
        │   ├── room: "living_room"
        │   ├── type: "light"
        │   ├── isOnline: true
        │   ├── isOn: false
        │   ├── esp32Id: "ESP32_RELAY1"
        │   └── lastUpdated: Timestamp
        │
        ├── {deviceId2}/
        │   ├── name: "Bedroom Fan"
        │   ├── room: "bedroom"
        │   ├── type: "fan"
        │   ├── isOnline: true
        │   ├── isOn: false
        │   ├── esp32Id: "ESP32_RELAY2"
        │   └── lastUpdated: Timestamp
        │
        └── {deviceId3}/
            ├── name: "Temperature Sensor"
            ├── room: "living_room"
            ├── type: "temperature"
            ├── isOnline: true
            ├── isOn: true
            ├── value: 24.5
            ├── unit: "°C"
            ├── esp32Id: "ESP32_DHT11"
            └── lastUpdated: Timestamp
```

### 2. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to manage their own devices
    match /smart_devices/{userId}/devices/{deviceId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. Firebase Realtime Database (Alternative)

If using RTDB instead of Firestore:

```json
{
  "smart_devices": {
    "{userId}": {
      "devices": {
        "{deviceId}": {
          "name": "Living Room Light",
          "isOn": false,
          "isOnline": true
        }
      }
    }
  }
}
```

---

## 🛠️ ESP32 Setup

### 1. Install Arduino IDE

1. Download: https://www.arduino.cc/en/software
2. Install Arduino IDE 2.x

### 2. Add ESP32 Board Support

1. Open Arduino IDE
2. Go to **File → Preferences**
3. Add to "Additional Board Manager URLs":
   ```
   https://dl.espressif.com/dl/package_esp32_index.json
   ```
4. Go to **Tools → Board → Boards Manager**
5. Search "ESP32"
6. Install "esp32 by Espressif Systems"

### 3. Install Required Libraries

**Tools → Manage Libraries**, search and install:

- `Firebase ESP32 Client` by Mobizt
- `ESP32Servo` by Kevin Harrington
- `DHT sensor library` by Adafruit

### 4. Configure ESP32 Code

Edit `esp32/domfix_smart_home.ino`:

```cpp
// WiFi credentials
#define WIFI_SSID "YOUR_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase config
#define FIREBASE_HOST "your-project.firebaseio.com"
#define FIREBASE_AUTH "your_database_secret"
#define USER_ID "your_firebase_user_id"

// Device IDs (copy from Firestore)
String lightDeviceId = "abc123";  // From Firestore
String fanDeviceId = "def456";
String doorDeviceId = "ghi789";
String tempDeviceId = "jkl012";
String ldrDeviceId = "mno345";
```

### 5. Upload to ESP32

1. Connect ESP32 via USB
2. Select: **Tools → Board → ESP32 Dev Module**
3. Select: **Tools → Port → COM X** (your port)
4. Click **Upload** button
5. Open **Serial Monitor** (115200 baud)
6. Watch for: "System ready!"

### 6. Verify Hardware

Check Serial Monitor output:

```
================================
DomFix ESP32 Smart Home
================================

Initializing hardware...
Hardware ready
Connecting to WiFi: YourWiFi
....
WiFi connected!
IP: 192.168.1.100
Connecting to Firebase...
Firebase connected!
System ready!
💓 Heartbeat sent
🌡️ Temp: 24.5C, Humidity: 60.0%
☀️ Brightness: 450 lux
```

---

## 📱 Flutter App Setup

### 1. Add IoT Screen to Navigation

Edit `lib/screens/main_screen.dart`:

```dart
import 'smart_home_screen.dart';

// Add to bottom navigation tabs
SmartHomeScreen(),
```

### 2. Initialize Demo Devices (Optional)

```dart
// In your main app or settings
await IoTService.instance.createDemoDevices();
```

### 3. Test Real-time Control

1. Open Smart Home screen
2. Add a device matching ESP32 device ID
3. Toggle device ON/OFF
4. Watch ESP32 Serial Monitor
5. Verify relay activates instantly

---

## 🧪 Testing Guide

### Test 1: Light Control

**Flutter App:**
1. Tap "Living Room Light"
2. Toggle switch to ON

**Expected Result:**
- UI shows "On" instantly
- ESP32 Serial: "Light: ON"
- Physical lamp turns ON
- Latency: < 1 second

### Test 2: Fan Control

**Flutter App:**
1. Tap "Bedroom Fan"
2. Toggle ON

**Expected Result:**
- Fan device shows green
- ESP32 activates Relay 2
- Physical fan runs

### Test 3: Door Servo

**Flutter App:**
1. Tap "Main Door"
2. Toggle to OPEN

**Expected Result:**
- Servo rotates 0° → 90°
- Door opens smoothly
- Takes 1-2 seconds

### Test 4: Temperature Sensor

**Expected Behavior:**
- ESP32 reads DHT11 every 5s
- Firebase updates automatically
- Flutter app shows real-time temp
- No user action needed

### Test 5: Offline Detection

**Test:**
1. Unplug ESP32
2. Wait 30 seconds

**Expected Result:**
- App shows devices as "Offline"
- Gray indicator appears
- Last updated timestamp visible

---

## 🔍 Troubleshooting

### ESP32 Won't Connect to WiFi

**Check:**
- WiFi SSID is correct (case-sensitive)
- Password is correct
- WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Router allows new devices

**Fix:**
```cpp
WiFi.disconnect();
WiFi.mode(WIFI_STA);
WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
```

### Firebase Connection Failed

**Check:**
- Firebase Host URL is correct
- Database Secret is valid
- Internet connection is stable
- Firestore rules allow access

**Debug:**
```cpp
Serial.println(Firebase.getErrorReason());
```

### Relay Not Switching

**Check:**
- Relay module has 5V power
- GPIO pins match code
- Relay is active LOW or HIGH (check module specs)

**Fix (if relay is active LOW):**
```cpp
digitalWrite(RELAY_LIGHT_PIN, lightState ? LOW : HIGH);
```

### Devices Show "Offline" in App

**Check:**
- ESP32 is powered ON
- Serial Monitor shows "Heartbeat sent"
- Firebase paths match exactly
- Device IDs match in both systems

**Fix:**
- Restart ESP32
- Check device ID strings
- Verify Firebase rules

### Servo Not Moving

**Check:**
- Servo has separate 5V power
- Signal wire on correct GPIO
- Servo is SG90 or compatible

**Test:**
```cpp
doorServo.write(90);  // Should move to 90°
```

### Sensor Reads NaN

**Check:**
- DHT11 has pull-up resistor (10kΩ)
- Proper 3-wire connection
- DHT library installed

**Fix:**
```cpp
if (isnan(temperature)) {
  Serial.println("DHT read failed!");
}
```

---

## 🚀 Next Steps

### Phase 1: Basic Control ✅
- Light ON/OFF
- Fan control
- Door servo
- Temperature reading

### Phase 2: Advanced Features
- [ ] Voice control (Google Assistant)
- [ ] Automation rules (if temp > 25°C, turn fan ON)
- [ ] Scheduling (turn light ON at 6 PM)
- [ ] Energy monitoring
- [ ] Multiple ESP32 boards

### Phase 3: Professional Features
- [ ] OTA updates (update ESP32 over WiFi)
- [ ] Device grouping (all living room devices)
- [ ] Scenes (Movie mode = lights dim, curtains close)
- [ ] Security alerts
- [ ] Smart notifications

---

## 📚 Additional Resources

- **ESP32 Docs:** https://docs.espressif.com
- **Firebase Docs:** https://firebase.google.com/docs
- **Arduino Reference:** https://www.arduino.cc/reference
- **DomFix GitHub:** https://github.com/your-repo

---

## 🆘 Support

Issues? Contact:
- GitHub Issues
- Email: support@domfix.app
- Discord: DomFix Community

---

**Built with ❤️ by DomFix Team**
