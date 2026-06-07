# 🚀 DomFix ESP32 Quick Start

**Get your smart home running in 10 minutes**

---

## ⚡ Super Quick Setup

### 1. Hardware (5 min)

**Connect ESP32:**
```
ESP32 Pin → Component
GPIO 25   → Relay 1 (Light)
GPIO 26   → Relay 2 (Fan)
GPIO 27   → Servo (Door)
GPIO 14   → DHT11 (Temp)
GPIO 34   → LDR (Light sensor)
5V        → Power all components
GND       → Common ground
```

### 2. ESP32 Code (3 min)

**Edit `esp32/domfix_smart_home.ino`:**

```cpp
// Change these 3 lines
#define WIFI_SSID "YourWiFi"
#define WIFI_PASSWORD "YourPassword"
#define USER_ID "your_firebase_user_id"
```

**Upload:**
1. Connect ESP32 via USB
2. Open Arduino IDE
3. Tools → Board → ESP32 Dev Module
4. Click Upload ⬆️
5. Done! ✅

### 3. Flutter App (2 min)

**Add demo devices:**

```dart
// Run this once in your app
await IoTService.instance.createDemoDevices();
```

**Or manually in app:**
1. Open Smart Home tab
2. Tap "Add Device"
3. Name: "Living Room Light"
4. Type: Light
5. Room: Living Room
6. Save ✅

---

## 🎯 First Test

**Control a real lamp:**

1. Open DomFix app
2. Go to Smart Home screen
3. See "Living Room Light" card
4. Tap the switch
5. **💡 Physical lamp turns ON instantly!**

---

## 📊 How It Works

```
You tap "Light ON" in app
         ↓
Firebase updates: isOn = true
         ↓
ESP32 sees change (< 1 second)
         ↓
Relay activates
         ↓
💡 LAMP TURNS ON!
```

---

## 🔥 Get Device IDs

**Method 1: From App**
1. Add device in Smart Home screen
2. Check Firestore console
3. Copy document ID

**Method 2: From Firestore**
```
smart_devices/{userId}/devices/{THIS_IS_THE_ID}
```

**Update ESP32 code:**
```cpp
String lightDeviceId = "paste_id_here";
String fanDeviceId = "paste_id_here";
```

---

## ✅ Success Checklist

- [ ] ESP32 connects to WiFi
- [ ] Serial Monitor shows "System ready!"
- [ ] Devices appear in app
- [ ] Toggle switch = relay activates
- [ ] Temperature shows in app
- [ ] Devices show "Online" status

---

## ⚠️ Quick Fixes

**ESP32 won't connect?**
```cpp
// Add before WiFi.begin()
WiFi.mode(WIFI_STA);
delay(100);
```

**Devices offline?**
- Check USER_ID matches your Firebase auth UID
- Verify device IDs match exactly
- Restart ESP32

**Relay not working?**
- Try reversing HIGH/LOW in code
- Check 5V power to relay module

---

## 📱 App Screens

**Smart Home Screen shows:**
- All devices in grid layout
- Online/offline status
- Quick ON/OFF controls
- Real-time sensor data
- Room filtering

**Beautiful UI:**
- Minimal design
- Smooth animations
- Production-ready
- Google Home quality

---

## 🎨 Supported Devices

### Controllable
- ✅ Lights
- ✅ Fans
- ✅ Doors (servo)
- ✅ Switches
- ✅ Outlets
- ✅ Locks
- ✅ Curtains
- ✅ AC/Heater
- ✅ TV/Speakers

### Sensors
- ✅ Temperature
- ✅ Humidity
- ✅ Brightness
- ✅ Motion
- ✅ Touch

---

## 🚀 Next Features

**Easy to add:**
- More ESP32 devices
- Voice control
- Automation rules
- Scheduling
- Scenes
- Energy monitoring

**All scalable!**

---

## 📚 Full Guide

Need details? See:
- `ESP32_IOT_GUIDE.md` - Complete documentation
- `esp32/` folder - Arduino code
- `lib/services/iot_service.dart` - Flutter service
- `lib/screens/smart_home_screen.dart` - UI

---

## 🆘 Help

**Not working?**
1. Check Serial Monitor output
2. Verify Firebase rules deployed
3. Confirm WiFi is 2.4GHz
4. Ensure device IDs match

**Still stuck?**
Open issue on GitHub with:
- Serial Monitor output
- Error messages
- Hardware setup photo

---

**Now go control some real hardware! 🎉**
