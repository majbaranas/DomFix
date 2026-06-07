import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/smart_device.dart';

/// Professional IoT Service for ESP32 + Firebase integration
/// Handles real-time device control and synchronization
class IoTService {
  IoTService._();
  static final IoTService instance = IoTService._();
  factory IoTService() => instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get current user's devices collection reference
  CollectionReference<Map<String, dynamic>>? get _devicesRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('smart_devices').doc(uid).collection('devices');
  }

  /// Real-time stream of all devices
  Stream<List<SmartDevice>> devicesStream() {
    if (_devicesRef == null) return const Stream.empty();
    return _devicesRef!
        .orderBy('room')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SmartDevice.fromFirestore(doc)).toList());
  }

  /// Stream devices by room
  Stream<List<SmartDevice>> devicesByRoom(String room) {
    if (_devicesRef == null) return const Stream.empty();
    return _devicesRef!
        .where('room', isEqualTo: room)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SmartDevice.fromFirestore(doc)).toList());
  }

  /// Stream devices by type
  Stream<List<SmartDevice>> devicesByType(SmartDeviceType type) {
    if (_devicesRef == null) return const Stream.empty();
    return _devicesRef!
        .where('type', isEqualTo: type.key)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SmartDevice.fromFirestore(doc)).toList());
  }

  /// Get single device stream
  Stream<SmartDevice?> deviceStream(String deviceId) {
    if (_devicesRef == null) return const Stream.empty();
    return _devicesRef!
        .doc(deviceId)
        .snapshots()
        .map((doc) => doc.exists ? SmartDevice.fromFirestore(doc) : null);
  }

  /// Add a new device
  Future<String> addDevice(SmartDevice device) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final doc = await _devicesRef!.add(device.toFirestore());
    debugPrint('🔧 [IoT] Device added: ${device.name} (${doc.id})');
    return doc.id;
  }

  /// Update device
  Future<void> updateDevice(String deviceId, Map<String, dynamic> updates) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    updates['lastUpdated'] = FieldValue.serverTimestamp();
    await _devicesRef!.doc(deviceId).update(updates);
    debugPrint('🔄 [IoT] Device updated: $deviceId');
  }

  /// Delete device
  Future<void> deleteDevice(String deviceId) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    await _devicesRef!.doc(deviceId).delete();
    debugPrint('🗑️ [IoT] Device deleted: $deviceId');
  }

  /// Toggle device ON/OFF (main control method for ESP32)
  Future<void> toggleDevice(String deviceId, bool isOn) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    await _devicesRef!.doc(deviceId).update({
      'isOn': isOn,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    
    debugPrint('💡 [IoT] Device ${isOn ? 'ON' : 'OFF'}: $deviceId');
  }

  /// Update device online status (ESP32 heartbeat)
  Future<void> updateDeviceStatus(String deviceId, bool isOnline) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    await _devicesRef!.doc(deviceId).update({
      'isOnline': isOnline,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Update sensor value (for temperature, humidity, brightness, etc.)
  Future<void> updateSensorValue(
    String deviceId,
    double value, {
    String? unit,
  }) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final updates = <String, dynamic>{
      'value': value,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    
    if (unit != null) updates['unit'] = unit;
    
    await _devicesRef!.doc(deviceId).update(updates);
    debugPrint('📊 [IoT] Sensor updated: $deviceId = $value${unit ?? ''}');
  }

  /// Bulk update multiple devices (for scenes/automation)
  Future<void> updateMultipleDevices(
    Map<String, Map<String, dynamic>> deviceUpdates,
  ) async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final batch = _firestore.batch();
    
    for (final entry in deviceUpdates.entries) {
      final deviceId = entry.key;
      final updates = entry.value;
      updates['lastUpdated'] = FieldValue.serverTimestamp();
      
      batch.update(_devicesRef!.doc(deviceId), updates);
    }
    
    await batch.commit();
    debugPrint('🔄 [IoT] Bulk update: ${deviceUpdates.length} devices');
  }

  /// Get devices count
  Future<int> getDevicesCount() async {
    if (_devicesRef == null) return 0;
    final snapshot = await _devicesRef!.count().get();
    return snapshot.count ?? 0;
  }

  /// Get online devices count
  Future<int> getOnlineDevicesCount() async {
    if (_devicesRef == null) return 0;
    final snapshot = await _devicesRef!.where('isOnline', isEqualTo: true).count().get();
    return snapshot.count ?? 0;
  }

  /// Check if ESP32 device exists
  Future<bool> esp32Exists(String esp32Id) async {
    if (_devicesRef == null) return false;
    final query = await _devicesRef!.where('esp32Id', isEqualTo: esp32Id).limit(1).get();
    return query.docs.isNotEmpty;
  }

  /// Get device by ESP32 ID (for hardware mapping)
  Future<SmartDevice?> getDeviceByEsp32Id(String esp32Id) async {
    if (_devicesRef == null) return null;
    final query = await _devicesRef!.where('esp32Id', isEqualTo: esp32Id).limit(1).get();
    if (query.docs.isEmpty) return null;
    return SmartDevice.fromFirestore(query.docs.first);
  }

  /// Turn all devices ON
  Future<void> turnAllOn() async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final devices = await _devicesRef!.where('isOnline', isEqualTo: true).get();
    final batch = _firestore.batch();
    
    for (final doc in devices.docs) {
      batch.update(doc.reference, {
        'isOn': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('💡 [IoT] All devices turned ON');
  }

  /// Turn all devices OFF
  Future<void> turnAllOff() async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final devices = await _devicesRef!.where('isOnline', isEqualTo: true).get();
    final batch = _firestore.batch();
    
    for (final doc in devices.docs) {
      batch.update(doc.reference, {
        'isOn': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('💡 [IoT] All devices turned OFF');
  }

  /// Clean up offline devices (remove devices offline for > 24 hours)
  Future<void> cleanupOfflineDevices() async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final devices = await _devicesRef!
        .where('isOnline', isEqualTo: false)
        .where('lastUpdated', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    
    final batch = _firestore.batch();
    for (final doc in devices.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    debugPrint('🧹 [IoT] Cleaned up ${devices.docs.length} offline devices');
  }

  /// Create default demo devices (for testing)
  Future<void> createDemoDevices() async {
    if (_devicesRef == null) throw Exception('User not authenticated');
    
    final demoDevices = [
      SmartDevice(
        id: '',
        name: 'Living Room Light',
        room: 'living_room',
        type: SmartDeviceType.light,
        isOnline: true,
        isOn: false,
        lastUpdated: DateTime.now(),
        esp32Id: 'ESP32_RELAY1',
      ),
      SmartDevice(
        id: '',
        name: 'Bedroom Fan',
        room: 'bedroom',
        type: SmartDeviceType.fan,
        isOnline: true,
        isOn: false,
        lastUpdated: DateTime.now(),
        esp32Id: 'ESP32_RELAY2',
      ),
      SmartDevice(
        id: '',
        name: 'Main Door',
        room: 'hallway',
        type: SmartDeviceType.door,
        isOnline: true,
        isOn: false,
        lastUpdated: DateTime.now(),
        esp32Id: 'ESP32_SERVO',
      ),
      SmartDevice(
        id: '',
        name: 'Temperature Sensor',
        room: 'living_room',
        type: SmartDeviceType.temperature,
        isOnline: true,
        isOn: true,
        value: 24.5,
        unit: '°C',
        lastUpdated: DateTime.now(),
        esp32Id: 'ESP32_DHT11',
      ),
      SmartDevice(
        id: '',
        name: 'Light Sensor',
        room: 'living_room',
        type: SmartDeviceType.brightness,
        isOnline: true,
        isOn: true,
        value: 450,
        unit: 'lux',
        lastUpdated: DateTime.now(),
        esp32Id: 'ESP32_LDR',
      ),
    ];
    
    for (final device in demoDevices) {
      await addDevice(device);
    }
    
    debugPrint('✅ [IoT] Demo devices created');
  }
}
