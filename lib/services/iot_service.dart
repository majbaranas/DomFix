import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Simplified IoT Service for controlling a single LED via Firebase RTDB
class IoTService {
  IoTService._();
  static final IoTService instance = IoTService._();
  factory IoTService() => instance;

  final _rtdb = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  DatabaseReference? get _ledRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _rtdb.ref('smart_devices/$uid/devices/ESP32_LED/isOn');
  }

  /// Stream to listen to the LED state in real-time
  Stream<bool> get ledStateStream {
    if (_ledRef == null) return Stream.value(false);
    return _ledRef!.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is bool) return value;
      return false;
    });
  }

  /// Toggle the LED ON/OFF
  Future<void> toggleLed(bool isOn) async {
    if (_ledRef == null) return;
    try {
      await _ledRef!.set(isOn);
      debugPrint('⚡ [IoT] LED set to $isOn in Firebase');
    } catch (e) {
      debugPrint('⚠️ [IoT Error] Failed to toggle LED: $e');
    }
  }
}
