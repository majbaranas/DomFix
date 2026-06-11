import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_log.dart';

class ActivityLogService {
  ActivityLogService._();
  static final ActivityLogService instance = ActivityLogService._();
  factory ActivityLogService() => instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get _logsRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('smart_home_logs').doc(uid).collection('logs');
  }

  /// Stream of recent activity logs
  Stream<List<ActivityLog>> getLogs({int limit = 50}) {
    if (_logsRef == null) return const Stream.empty();
    return _logsRef!
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ActivityLog.fromFirestore(doc)).toList());
  }

  /// Add a new log entry
  Future<void> logEvent({
    required String title,
    required String description,
    required LogType type,
    String? deviceId,
    String? deviceName,
  }) async {
    if (_logsRef == null) return;

    try {
      final log = ActivityLog(
        id: '',
        title: title,
        description: description,
        type: type,
        timestamp: DateTime.now(),
        deviceId: deviceId,
        deviceName: deviceName,
      );

      await _logsRef!.add(log.toFirestore());
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    if (_logsRef == null) return;
    
    final snapshot = await _logsRef!.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
