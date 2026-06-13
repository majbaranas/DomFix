import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/smart_device.dart';
import '../models/activity_log.dart';
import 'activity_log_service.dart';
import 'demo_simulator_service.dart';

/// Dynamic multi-device IoT Service using Firebase RTDB
class IoTService {
  IoTService._();
  static final IoTService instance = IoTService._();
  factory IoTService() => instance;

  final _rtdb = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  /// Base reference for the current user's smart devices in RTDB
  DatabaseReference? get _userDevicesRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _rtdb.ref('smart_devices/$uid/devices');
  }

  /// Monitor real-time connection status to Firebase RTDB
  Stream<bool> get connectionStatusStream {
    return _rtdb.ref('.info/connected').onValue.map((event) {
      return (event.snapshot.value as bool?) ?? false;
    });
  }

  /// Stream of all devices for the current user
  Stream<List<SmartDevice>> devicesStream() {
    if (_userDevicesRef == null) return Stream.value([]);
    
    return _userDevicesRef!.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <SmartDevice>[];

      final devices = <SmartDevice>[];
      final mapData = Map<dynamic, dynamic>.from(data);
      
      mapData.forEach((key, value) {
        if (value is Map) {
          try {
            devices.add(SmartDevice.fromRtdb(key.toString(), value));
          } catch (e) {
            debugPrint('⚠️ [IoT Error] Failed to parse device $key: $e');
          }
        }
      });
      
      // Sort: Controllable first, then by name
      devices.sort((a, b) {
        if (a.isSensor != b.isSensor) {
          return a.isSensor ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
      
      return devices;
    });
  }

  /// Stream a single device by ID
  Stream<SmartDevice?> deviceStream(String deviceId) {
    if (_userDevicesRef == null) return Stream.value(null);
    return _userDevicesRef!.child(deviceId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return null;
      try {
        return SmartDevice.fromRtdb(deviceId, Map<dynamic, dynamic>.from(data));
      } catch (e) {
        debugPrint('⚠️ [IoT Error] Failed to parse device $deviceId: $e');
        return null;
      }
    });
  }

  /// Toggle device ON/OFF
  Future<void> toggleDevice(String deviceId, bool isOn) async {
    if (_userDevicesRef == null) return;
    try {
      await _userDevicesRef!.child(deviceId).update({
        'isOn': isOn,
        'lastUpdated': ServerValue.timestamp,
      });
      debugPrint('⚡ [IoT] Device $deviceId turned ${isOn ? "ON" : "OFF"}');
      
      final snapshot = await _userDevicesRef!.child(deviceId).child('name').get();
      final name = snapshot.value?.toString() ?? deviceId;

      ActivityLogService.instance.logEvent(
        title: '$name turned ${isOn ? "ON" : "OFF"}',
        description: isOn ? 'Device was turned on' : 'Device was turned off',
        type: LogType.deviceToggled,
        deviceId: deviceId,
        deviceName: name,
      );
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Failed to toggle device $deviceId: $e');
    }
  }

  /// Change specific device value (brightness, speed, angle, etc.)
  Future<void> changeDeviceValue(String deviceId, double value, {String valueKey = 'value'}) async {
    if (_userDevicesRef == null) return;
    try {
      await _userDevicesRef!.child(deviceId).update({
        valueKey: value,
        'lastUpdated': ServerValue.timestamp,
      });
      debugPrint('⚡ [IoT] Device $deviceId $valueKey set to $value');
      
      final snapshot = await _userDevicesRef!.child(deviceId).child('name').get();
      final name = snapshot.value?.toString() ?? deviceId;

      ActivityLogService.instance.logEvent(
        title: '$name Adjusted',
        description: '$valueKey changed to $value',
        type: LogType.deviceToggled,
        deviceId: deviceId,
        deviceName: name,
      );
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Failed to change value for $deviceId: $e');
    }
  }

  /// Remove a device (mostly for demo cleanup)
  Future<void> removeDevice(String deviceId) async {
    if (_userDevicesRef == null) return;
    await _userDevicesRef!.child(deviceId).remove();
  }

  // ─── Bulk Operations ──────────────────────────────────────────
  
  Future<void> setAllDevicesOfType(String type, bool isOn) async {
    if (_userDevicesRef == null) return;
    try {
      final snapshot = await _userDevicesRef!.get();
      if (snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final updates = <String, dynamic>{};
        for (final entry in data.entries) {
          if (entry.value is Map && entry.value['type'] == type) {
            updates['${entry.key}/isOn'] = isOn;
            updates['${entry.key}/lastUpdated'] = ServerValue.timestamp;
          }
        }
        if (updates.isNotEmpty) {
          await _userDevicesRef!.update(updates);
          
          ActivityLogService.instance.logEvent(
            title: 'Bulk Action: ${isOn ? "Turn ON" : "Turn OFF"}',
            description: 'All $type devices were turned ${isOn ? "ON" : "OFF"}.',
            type: LogType.automationTriggered,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Bulk toggle failed: $e');
    }
  }

  Future<void> activateMode(String modeName) async {
    if (_userDevicesRef == null) return;
    try {
      final snapshot = await _userDevicesRef!.get();
      if (snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final updates = <String, dynamic>{};
        
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final type = entry.value['type'];
            if (modeName == 'Night Mode') {
              if (type == 'light') updates['${entry.key}/isOn'] = false;
              if (type == 'door') updates['${entry.key}/isOn'] = false; // Closed
            } else if (modeName == 'Away Mode') {
              if (type == 'light') updates['${entry.key}/isOn'] = false;
              if (type == 'fan') updates['${entry.key}/isOn'] = false;
              if (type == 'door') updates['${entry.key}/isOn'] = false; // Closed
            } else if (modeName == 'Energy Saving') {
              if (type == 'light') {
                updates['${entry.key}/brightness'] = 0.3; // Dim lights
              }
              if (type == 'fan') {
                updates['${entry.key}/speed'] = 0.3; // Slow fans
              }
            }
          }
        }
        
        if (updates.isNotEmpty) {
          await _userDevicesRef!.update(updates);
        }
      }
      
      ActivityLogService.instance.logEvent(
        title: '$modeName Activated',
        description: 'System automatically adjusted devices for $modeName.',
        type: LogType.automationTriggered,
      );
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Activate mode failed: $e');
    }
  }

  // ─── Demo Mode ──────────────────────────────────────────────

  Future<void> toggleDemoMode() async {
    _isDemoMode = !_isDemoMode;
    if (_isDemoMode) {
      await _populateDemoDevices();
      DemoSimulatorService.instance.start();
    } else {
      DemoSimulatorService.instance.stop();
      await _cleanupDemoDevices();
    }
  }

  Future<void> _populateDemoDevices() async {
    if (_userDevicesRef == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final demoDevices = {
      'ESP32_LED': {
        'name': 'Living Room Light',
        'room': 'living_room',
        'type': 'light',
        'isOnline': true,
        'isOn': true,
        'brightness': 0.8,
        'lastUpdated': now,
        'isDemo': true,
      },
      'ESP32_FAN': {
        'name': 'Bedroom Fan',
        'room': 'bedroom',
        'type': 'fan',
        'isOnline': true,
        'isOn': false,
        'speed': 0.5,
        'lastUpdated': now,
        'isDemo': true,
      },
      'ESP32_SERVO': {
        'name': 'Main Door',
        'room': 'hallway',
        'type': 'door',
        'isOnline': true,
        'isOn': false, // Closed
        'angle': 0.0,
        'lastUpdated': now,
        'isDemo': true,
      },
      'ESP32_DHT11_T': {
        'name': 'Living Room Temp',
        'room': 'living_room',
        'type': 'temperature',
        'isOnline': true,
        'isOn': true,
        'value': 23.5,
        'unit': '°C',
        'lastUpdated': now,
        'isDemo': true,
      },
      'ESP32_DHT11_H': {
        'name': 'Living Room Hum',
        'room': 'living_room',
        'type': 'humidity',
        'isOnline': true,
        'isOn': true,
        'value': 45.0,
        'unit': '%',
        'lastUpdated': now,
        'isDemo': true,
      },
      'ESP32_LDR': {
        'name': 'Outdoor Light',
        'room': 'garden',
        'type': 'brightness',
        'isOnline': true,
        'isOn': true,
        'value': 850.0,
        'unit': 'lux',
        'lastUpdated': now,
        'isDemo': true,
      },
    };

    try {
      await _userDevicesRef!.update(demoDevices);
      debugPrint('✅ [IoT] Demo devices populated');
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Failed to populate demo devices: $e');
    }
  }

  Future<void> _cleanupDemoDevices() async {
    if (_userDevicesRef == null) return;
    try {
      final snapshot = await _userDevicesRef!.get();
      if (snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is Map && entry.value['isDemo'] == true) {
            await _userDevicesRef!.child(entry.key.toString()).remove();
          }
        }
      }
      debugPrint('✅ [IoT] Demo devices cleaned up');
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Failed to cleanup demo devices: $e');
    }
  }

  // ─── Backward Compatibility for Old Code ───────────────────

  /// Stream to listen to the LED state in real-time (Backward compatibility)
  Stream<bool> get ledStateStream {
    if (_userDevicesRef == null) return Stream.value(false);
    return _userDevicesRef!.child('ESP32_LED/isOn').onValue.map((event) {
      return (event.snapshot.value as bool?) ?? false;
    });
  }

  /// Toggle the LED ON/OFF (Backward compatibility)
  Future<void> toggleLed(bool isOn) async {
    await toggleDevice('ESP32_LED', isOn);
  }
}
