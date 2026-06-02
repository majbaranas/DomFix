import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A home device registered by the user in the Control tab.
/// Stored at `users/{uid}/devices/{deviceId}`.
class UserDevice {
  final String id;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final DateTime createdAt;

  const UserDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory UserDevice.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserDevice(
      id: doc.id,
      name: (d['name'] as String? ?? 'Device').trim(),
      type: DeviceType.fromString(d['type'] as String? ?? ''),
      status: DeviceStatus.fromString(d['status'] as String? ?? ''),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.key,
        'status': status.key,
        'createdAt': FieldValue.serverTimestamp(),
      };

  UserDevice copyWith({DeviceStatus? status}) => UserDevice(
        id: id,
        name: name,
        type: type,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

enum DeviceType {
  ac('ac', 'Air Conditioner', Icons.ac_unit_rounded),
  thermostat('thermostat', 'Thermostat', Icons.thermostat_rounded),
  lights('lights', 'Lights', Icons.light_rounded),
  security('security', 'Security', Icons.security_rounded),
  waterHeater('water_heater', 'Water Heater', Icons.water_rounded),
  appliance('appliance', 'Appliance', Icons.kitchen_rounded),
  network('network', 'Network', Icons.router_rounded),
  solar('solar', 'Solar', Icons.solar_power_rounded),
  other('other', 'Other', Icons.devices_rounded);

  final String key;
  final String label;
  final IconData icon;
  const DeviceType(this.key, this.label, this.icon);

  static DeviceType fromString(String v) =>
      DeviceType.values.firstWhere((e) => e.key == v, orElse: () => DeviceType.other);
}

enum DeviceStatus {
  online('online'),
  offline('offline'),
  warning('warning');

  final String key;
  const DeviceStatus(this.key);

  static DeviceStatus fromString(String v) =>
      DeviceStatus.values.firstWhere((e) => e.key == v, orElse: () => DeviceStatus.offline);
}
