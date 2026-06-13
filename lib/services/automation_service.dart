import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_log.dart';
import '../models/automation.dart';
import '../models/smart_device.dart';
import 'activity_log_service.dart';
import 'iot_service.dart';

class AutomationService {
  AutomationService._();
  static final AutomationService instance = AutomationService._();
  factory AutomationService() => instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _iot = IoTService.instance;
  final _activityLog = ActivityLogService.instance;

  StreamSubscription? _devicesSub;
  List<AutomationRule> _activeRules = [];
  final Map<String, dynamic> _lastEvaluatedState = {};
  
  // Track last triggered times to avoid spamming
  final Map<String, DateTime> _lastTriggeredTimes = {};

  CollectionReference<Map<String, dynamic>>? get _rulesRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('smart_home_automations').doc(uid).collection('rules');
  }

  /// Initialize the engine
  void startEngine() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadRules();
        _listenToDevices();
      } else {
        stopEngine();
      }
    });
  }

  void stopEngine() {
    _devicesSub?.cancel();
    _activeRules.clear();
    _lastEvaluatedState.clear();
  }

  void _loadRules() {
    _rulesRef?.snapshots().listen((snapshot) {
      _activeRules = snapshot.docs.map((d) => AutomationRule.fromFirestore(d)).toList();
    });
  }

  void _listenToDevices() {
    _devicesSub?.cancel();
    _devicesSub = _iot.devicesStream().listen((devices) {
      _evaluateRules(devices);
    });
  }

  void _evaluateRules(List<SmartDevice> devices) {
    if (_activeRules.isEmpty) return;

    final deviceMap = {for (var d in devices) d.id: d};

    for (final rule in _activeRules) {
      if (!rule.isEnabled) continue;

      final sourceDevice = deviceMap[rule.condition.sourceDeviceId];
      if (sourceDevice == null) continue;

      dynamic currentValue;
      if (rule.condition.attribute == 'value') {
        currentValue = sourceDevice.value;
      } else if (rule.condition.attribute == 'isOn') {
        currentValue = sourceDevice.isOn;
      }

      if (rule.condition.evaluate(currentValue)) {
        // Prevent spam (cooldown of 30 seconds per rule)
        final lastTriggered = _lastTriggeredTimes[rule.id];
        if (lastTriggered != null && DateTime.now().difference(lastTriggered).inSeconds < 30) {
          continue;
        }

        _triggerAction(rule, deviceMap[rule.action.targetDeviceId], sourceDevice);
      }
    }
  }

  Future<void> _triggerAction(AutomationRule rule, SmartDevice? targetDevice, SmartDevice sourceDevice) async {
    if (targetDevice == null) return;
    
    _lastTriggeredTimes[rule.id] = DateTime.now();

    try {
      if (rule.action.attribute == 'isOn') {
        await _iot.toggleDevice(targetDevice.id, rule.action.value as bool);
      } else if (rule.action.attribute == 'brightness' || rule.action.attribute == 'speed') {
        await _iot.changeDeviceValue(targetDevice.id, (rule.action.value as num).toDouble(), valueKey: rule.action.attribute);
      }
      
      // Log it
      await _activityLog.logEvent(
        title: 'Automation Triggered',
        description: 'Rule "${rule.name}" triggered by ${sourceDevice.name}',
        type: LogType.automationTriggered,
        deviceName: targetDevice.name,
        deviceId: targetDevice.id,
      );
      
    } catch (e) {
      debugPrint('Failed to trigger automation action: $e');
    }
  }

  Stream<List<AutomationRule>> getRules() {
    if (_rulesRef == null) return const Stream.empty();
    return _rulesRef!.snapshots().map((snap) => snap.docs.map((d) => AutomationRule.fromFirestore(d)).toList());
  }

  Future<void> addRule(AutomationRule rule) async {
    await _rulesRef?.add(rule.toFirestore());
  }

  Future<void> deleteRule(String id) async {
    await _rulesRef?.doc(id).delete();
  }

  Future<void> toggleRule(String id, bool isEnabled) async {
    await _rulesRef?.doc(id).update({'isEnabled': isEnabled});
  }
}
