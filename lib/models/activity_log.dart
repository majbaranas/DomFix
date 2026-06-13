import 'package:cloud_firestore/cloud_firestore.dart';

enum LogType {
  deviceToggled('device_toggled'),
  sensorThreshold('sensor_threshold'),
  automationTriggered('automation_triggered'),
  aiRecommendation('ai_recommendation'),
  voiceCommand('voice_command'),
  connectionChange('connection_change'),
  error('error');

  final String key;
  const LogType(this.key);

  static LogType fromString(String key) {
    return values.firstWhere((e) => e.key == key, orElse: () => LogType.deviceToggled);
  }
}

class ActivityLog {
  final String id;
  final String title;
  final String description;
  final LogType type;
  final DateTime timestamp;
  final String? deviceId;
  final String? deviceName;

  const ActivityLog({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
    this.deviceId,
    this.deviceName,
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      title: data['title'] as String? ?? 'Unknown Event',
      description: data['description'] as String? ?? '',
      type: LogType.fromString(data['type'] as String? ?? 'device_toggled'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deviceId: data['deviceId'] as String?,
      deviceName: data['deviceName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'type': type.key,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': deviceId,
        'deviceName': deviceName,
      };
}
