import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simulates sensor data fluctuations when Demo Mode is active.
/// This ensures the Presentation Mode feels alive and realistic.
class DemoSimulatorService {
  DemoSimulatorService._();
  static final instance = DemoSimulatorService._();

  Timer? _timer;
  final _random = Random();
  final _rtdb = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  double _temp = 23.5;
  double _hum = 45.0;
  double _lux = 850.0;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _simulate());
    debugPrint('🧪 [DemoSimulator] Started');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🧪 [DemoSimulator] Stopped');
  }

  Future<void> _simulate() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _rtdb.ref('smart_devices/$uid/devices');

    try {
      _temp += (_random.nextDouble() * 0.4) - 0.2;
      if (_temp < 18) _temp = 18;
      if (_temp > 30) _temp = 30;

      _hum += (_random.nextDouble() * 2.0) - 1.0;
      if (_hum < 30) _hum = 30;
      if (_hum > 70) _hum = 70;

      _lux += (_random.nextDouble() * 40.0) - 20.0;
      if (_lux < 100) _lux = 100;
      if (_lux > 1000) _lux = 1000;

      await ref.update({
        'ESP32_DHT11_T/value': _temp,
        'ESP32_DHT11_H/value': _hum,
        'ESP32_LDR/value': _lux,
      });
    } catch (e) {
      debugPrint('⚠️ [DemoSimulator Error] $e');
    }
  }
}
