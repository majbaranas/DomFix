import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Smart IoT Device Model for real hardware control
/// Compatible with ESP32, Arduino, and smart home devices
class SmartDevice {
  final String id;
  final String name;
  final String room;
  final SmartDeviceType type;
  final bool isOnline;
  final bool isOn;
  final double? value; // For sensors (temp, humidity, brightness)
  final String? unit; // °C, %, lux
  final DateTime lastUpdated;
  final String? esp32Id; // ESP32 device identifier
  final Map<String, dynamic>? metadata; // Extra data
  
  // New specific control values
  final double? brightness; // 0.0 to 1.0
  final double? speed; // 0.0 to 1.0
  final String? color; // Hex color string
  final String? localIp; // ESP32 Local IP address for direct communication

  const SmartDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.type,
    required this.isOnline,
    required this.isOn,
    this.value,
    this.unit,
    required this.lastUpdated,
    this.esp32Id,
    this.metadata,
    this.brightness,
    this.speed,
    this.color,
    this.localIp,
  });

  factory SmartDevice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SmartDevice.fromMap(doc.id, data);
  }

  factory SmartDevice.fromMap(String id, Map<dynamic, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return SmartDevice(
      id: id,
      name: data['name'] as String? ?? 'Unknown Device',
      room: data['room'] as String? ?? 'Unknown',
      type: SmartDeviceType.fromString(data['type'] as String? ?? 'other'),
      isOnline: data['isOnline'] as bool? ?? false,
      isOn: data['isOn'] as bool? ?? false,
      value: (data['value'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
      lastUpdated: parseTime(data['lastUpdated']),
      esp32Id: data['esp32Id'] as String?,
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata'] as Map) : null,
      brightness: (data['brightness'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      color: data['color'] as String?,
      localIp: data['localIp'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'room': room,
        'type': type.key,
        'isOnline': isOnline,
        'isOn': isOn,
        'value': value,
        'unit': unit,
        // When using RTDB we often use ServerValue.timestamp, so we can let the service handle timestamping
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'esp32Id': esp32Id,
        'metadata': metadata,
        if (brightness != null) 'brightness': brightness,
        if (speed != null) 'speed': speed,
        if (color != null) 'color': color,
        if (localIp != null) 'localIp': localIp,
      };

  Map<String, dynamic> toFirestore() {
    final map = toMap();
    map['lastUpdated'] = FieldValue.serverTimestamp();
    return map;
  }

  SmartDevice copyWith({
    String? id,
    String? name,
    String? room,
    SmartDeviceType? type,
    bool? isOnline,
    bool? isOn,
    double? value,
    String? unit,
    DateTime? lastUpdated,
    String? esp32Id,
    Map<String, dynamic>? metadata,
    double? brightness,
    double? speed,
    String? color,
    String? localIp,
  }) =>
      SmartDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        room: room ?? this.room,
        type: type ?? this.type,
        isOnline: isOnline ?? this.isOnline,
        isOn: isOn ?? this.isOn,
        value: value ?? this.value,
        unit: unit ?? this.unit,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        esp32Id: esp32Id ?? this.esp32Id,
        metadata: metadata ?? this.metadata,
        brightness: brightness ?? this.brightness,
        speed: speed ?? this.speed,
        color: color ?? this.color,
        localIp: localIp ?? this.localIp,
      );

  /// Check if device was recently active (within 30 seconds)
  bool get isActive => 
      isOnline && DateTime.now().difference(lastUpdated).inSeconds < 30;
}

/// Smart device types supporting real IoT hardware
enum SmartDeviceType {
  light('light', 'Light', Icons.lightbulb_outline, Icons.lightbulb, true),
  fan('fan', 'Fan', Icons.air_outlined, Icons.air, true),
  door('door', 'Door', Icons.door_front_door_outlined, Icons.door_front_door, true),
  lock('lock', 'Lock', Icons.lock_outline, Icons.lock, true),
  temperature('temperature', 'Temperature', Icons.thermostat_outlined, Icons.thermostat, false),
  humidity('humidity', 'Humidity', Icons.water_drop_outlined, Icons.water_drop, false),
  motion('motion', 'Motion Sensor', Icons.sensors_outlined, Icons.sensors, false),
  brightness('brightness', 'Light Sensor', Icons.wb_sunny_outlined, Icons.wb_sunny, false),
  switch_device('switch', 'Switch', Icons.toggle_off_outlined, Icons.toggle_on, true),
  outlet('outlet', 'Outlet', Icons.power_outlined, Icons.power, true),
  camera('camera', 'Camera', Icons.videocam_outlined, Icons.videocam, true),
  thermostat('thermostat', 'Thermostat', Icons.device_thermostat_outlined, Icons.device_thermostat, true),
  alarm('alarm', 'Alarm', Icons.alarm_outlined, Icons.alarm, true),
  speaker('speaker', 'Speaker', Icons.speaker_outlined, Icons.speaker, true),
  tv('tv', 'TV', Icons.tv_outlined, Icons.tv, true),
  ac('ac', 'Air Conditioner', Icons.ac_unit_outlined, Icons.ac_unit, true),
  heater('heater', 'Heater', Icons.whatshot_outlined, Icons.whatshot, true),
  curtain('curtain', 'Curtain', Icons.curtains_outlined, Icons.curtains, true),
  garage('garage', 'Garage', Icons.garage_outlined, Icons.garage, true),
  other('other', 'Other', Icons.devices_outlined, Icons.devices, true);

  final String key;
  final String label;
  final IconData iconOff;
  final IconData iconOn;
  final bool isControllable; // Can be turned on/off

  const SmartDeviceType(
    this.key,
    this.label,
    this.iconOff,
    this.iconOn,
    this.isControllable,
  );

  static SmartDeviceType fromString(String key) =>
      values.firstWhere((e) => e.key == key, orElse: () => SmartDeviceType.other);

  IconData getIcon(bool isOn) => isOn ? iconOn : iconOff;
}

/// Room categories for organizing devices
enum SmartRoom {
  livingRoom('living_room', 'Living Room', Icons.living_outlined),
  bedroom('bedroom', 'Bedroom', Icons.bed_outlined),
  kitchen('kitchen', 'Kitchen', Icons.kitchen_outlined),
  bathroom('bathroom', 'Bathroom', Icons.bathroom_outlined),
  office('office', 'Office', Icons.work_outline),
  garage('garage', 'Garage', Icons.garage_outlined),
  garden('garden', 'Garden', Icons.yard_outlined),
  hallway('hallway', 'Hallway', Icons.door_sliding_outlined),
  other('other', 'Other', Icons.home_outlined);

  final String key;
  final String label;
  final IconData icon;

  const SmartRoom(this.key, this.label, this.icon);

  static SmartRoom fromString(String key) =>
      values.firstWhere((e) => e.key == key, orElse: () => SmartRoom.other);
}
