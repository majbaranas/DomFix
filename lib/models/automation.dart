import 'package:cloud_firestore/cloud_firestore.dart';

enum ConditionType {
  equals,
  greaterThan,
  lessThan,
}

class AutomationCondition {
  final String sourceDeviceId;
  final String attribute; // e.g. 'value' (for sensors), 'isOn'
  final ConditionType operator;
  final dynamic targetValue;

  const AutomationCondition({
    required this.sourceDeviceId,
    required this.attribute,
    required this.operator,
    required this.targetValue,
  });

  factory AutomationCondition.fromMap(Map<String, dynamic> map) {
    return AutomationCondition(
      sourceDeviceId: map['sourceDeviceId'] as String,
      attribute: map['attribute'] as String,
      operator: ConditionType.values.firstWhere((e) => e.name == map['operator']),
      targetValue: map['targetValue'],
    );
  }

  Map<String, dynamic> toMap() => {
        'sourceDeviceId': sourceDeviceId,
        'attribute': attribute,
        'operator': operator.name,
        'targetValue': targetValue,
      };

  bool evaluate(dynamic currentValue) {
    if (currentValue == null) return false;
    
    switch (operator) {
      case ConditionType.equals:
        return currentValue == targetValue;
      case ConditionType.greaterThan:
        return currentValue is num && targetValue is num && currentValue > targetValue;
      case ConditionType.lessThan:
        return currentValue is num && targetValue is num && currentValue < targetValue;
    }
  }
}

class AutomationAction {
  final String targetDeviceId;
  final String attribute; // e.g. 'isOn', 'brightness'
  final dynamic value;

  const AutomationAction({
    required this.targetDeviceId,
    required this.attribute,
    required this.value,
  });

  factory AutomationAction.fromMap(Map<String, dynamic> map) {
    return AutomationAction(
      targetDeviceId: map['targetDeviceId'] as String,
      attribute: map['attribute'] as String,
      value: map['value'],
    );
  }

  Map<String, dynamic> toMap() => {
        'targetDeviceId': targetDeviceId,
        'attribute': attribute,
        'value': value,
      };
}

class AutomationRule {
  final String id;
  final String name;
  final bool isEnabled;
  final AutomationCondition condition;
  final AutomationAction action;

  const AutomationRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.condition,
    required this.action,
  });

  factory AutomationRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AutomationRule(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Rule',
      isEnabled: data['isEnabled'] as bool? ?? true,
      condition: AutomationCondition.fromMap(Map<String, dynamic>.from(data['condition'] as Map)),
      action: AutomationAction.fromMap(Map<String, dynamic>.from(data['action'] as Map)),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'isEnabled': isEnabled,
        'condition': condition.toMap(),
        'action': action.toMap(),
      };
}
