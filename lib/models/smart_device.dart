import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ESP32 device category identifiers — matches the Firebase RTDB keys
/// written by the ESP32 firmware (e.g. `smart_devices/{uid}/devices/ESP32_LED`).
enum Esp32Category {
  led('ESP32_LED', 'Smart Light', SmartDeviceType.light),
  fan('ESP32_FAN', 'Smart Fan', SmartDeviceType.fan),
  servo('ESP32_SERVO', 'Smart Door', SmartDeviceType.door),
  dht11Temp('ESP32_DHT11_T', 'Temperature', SmartDeviceType.temperature),
  dht11Humidity('ESP32_DHT11_H', 'Humidity', SmartDeviceType.humidity),
  ldr('ESP32_LDR', 'Light Sensor', SmartDeviceType.brightness),
  touch('ESP32_TOUCH', 'Touch Sensor', SmartDeviceType.motion);

  final String key;
  final String defaultName;
  final SmartDeviceType defaultType;

  const Esp32Category(this.key, this.defaultName, this.defaultType);

  static Esp32Category? fromString(String key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// Whether this category represents a sensor (non-controllable)
  bool get isSensor => !defaultType.isControllable;
}

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

  // Control values
  final double? brightness; // 0.0 to 1.0
  final double? speed; // 0.0 to 1.0
  final double? angle; // 0 to 180 for servo
  final String? color; // Hex color string
  final String? localIp; // ESP32 Local IP address for direct communication

  // ESP32 category mapping
  final Esp32Category? category;

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
    this.angle,
    this.color,
    this.localIp,
    this.category,
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
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
      brightness: (data['brightness'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      angle: (data['angle'] as num?)?.toDouble(),
      color: data['color'] as String?,
      localIp: data['localIp'] as String?,
      category: data['category'] != null
          ? Esp32Category.fromString(data['category'] as String)
          : Esp32Category.fromString(id), // fallback: use the doc ID as category key
    );
  }

  /// Create a SmartDevice from a Firebase RTDB snapshot.
  ///
  /// [key] is the RTDB child key (e.g. "ESP32_LED").
  /// [data] is the child value map.
  factory SmartDevice.fromRtdb(String key, Map<dynamic, dynamic> data) {
    final cat = Esp32Category.fromString(key);
    final type = cat?.defaultType ??
        SmartDeviceType.fromString(data['type'] as String? ?? 'other');

    // Determine unit for sensors
    String? unit;
    if (cat == Esp32Category.dht11Temp) {
      unit = '°C';
    } else if (cat == Esp32Category.dht11Humidity) {
      unit = '%';
    } else if (cat == Esp32Category.ldr) {
      unit = 'lux';
    }

    DateTime parseTime(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return SmartDevice(
      id: key,
      name: data['name'] as String? ?? cat?.defaultName ?? key,
      room: data['room'] as String? ?? 'living_room',
      type: type,
      isOnline: data['isOnline'] as bool? ?? false,
      isOn: data['isOn'] as bool? ?? false,
      value: (data['value'] as num?)?.toDouble(),
      unit: data['unit'] as String? ?? unit,
      lastUpdated: parseTime(data['lastUpdated'] ?? 0),
      esp32Id: data['esp32Id'] as String? ?? key,
      brightness: (data['brightness'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      angle: (data['angle'] as num?)?.toDouble(),
      color: data['color'] as String?,
      localIp: data['localIp'] as String?,
      category: cat,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
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
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'esp32Id': esp32Id,
        'metadata': metadata,
        if (brightness != null) 'brightness': brightness,
        if (speed != null) 'speed': speed,
        if (angle != null) 'angle': angle,
        if (color != null) 'color': color,
        if (localIp != null) 'localIp': localIp,
        if (category != null) 'category': category!.key,
      };

  /// Serialize for Firebase RTDB (no FieldValue, plain types only).
  Map<String, dynamic> toRtdb() => {
        'name': name,
        'room': room,
        'type': type.key,
        'isOnline': isOnline,
        'isOn': isOn,
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        if (brightness != null) 'brightness': brightness,
        if (speed != null) 'speed': speed,
        if (angle != null) 'angle': angle,
        if (color != null) 'color': color,
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
    double? angle,
    String? color,
    String? localIp,
    Esp32Category? category,
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
        angle: angle ?? this.angle,
        color: color ?? this.color,
        localIp: localIp ?? this.localIp,
        category: category ?? this.category,
      );

  /// Whether this device is a read-only sensor
  bool get isSensor => !type.isControllable;

  /// Check if device was recently active (within 30 seconds)
  bool get isActive =>
      isOnline && DateTime.now().difference(lastUpdated).inSeconds < 30;

  /// Friendly status text
  String get statusText {
    if (!isOnline) return 'Offline';
    if (isSensor) {
      if (value != null) return '${value!.toStringAsFixed(1)}${unit ?? ''}';
      return 'Reading...';
    }
    return isOn ? 'On' : 'Off';
  }
}

/// Smart device types supporting real IoT hardware
enum SmartDeviceType {
  light('light', 'Light', Icons.lightbulb_outline, Icons.lightbulb, true),
  fan('fan', 'Fan', Icons.air_outlined, Icons.air, true),
  door('door', 'Door', Icons.door_front_door_outlined, Icons.door_front_door,
      true),
  lock('lock', 'Lock', Icons.lock_outline, Icons.lock, true),
  temperature('temperature', 'Temperature', Icons.thermostat_outlined,
      Icons.thermostat, false),
  humidity('humidity', 'Humidity', Icons.water_drop_outlined, Icons.water_drop,
      false),
  motion('motion', 'Motion Sensor', Icons.sensors_outlined, Icons.sensors,
      false),
  brightness('brightness', 'Light Sensor', Icons.wb_sunny_outlined,
      Icons.wb_sunny, false),
  switch_device(
      'switch', 'Switch', Icons.toggle_off_outlined, Icons.toggle_on, true),
  outlet('outlet', 'Outlet', Icons.power_outlined, Icons.power, true),
  camera('camera', 'Camera', Icons.videocam_outlined, Icons.videocam, true),
  thermostat('thermostat', 'Thermostat', Icons.device_thermostat_outlined,
      Icons.device_thermostat, true),
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
