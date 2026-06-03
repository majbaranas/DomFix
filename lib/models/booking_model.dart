import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String chatId;
  final String clientId;
  final String technicianId;
  final List<String> participants;
  final String technicianName;
  final String serviceId;
  final String serviceName;
  final DateTime scheduledAt;
  final String scheduledTimeLabel;
  final String description;
  final String urgency;
  final String status;
  final List<String> imageUrls;
  final int estimatedDurationMinutes;
  final double estimatedPriceMin;
  final double estimatedPriceMax;
  final double technicianFee;
  final double platformFee;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.chatId,
    required this.clientId,
    required this.technicianId,
    required this.participants,
    required this.technicianName,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledAt,
    required this.scheduledTimeLabel,
    required this.description,
    required this.urgency,
    required this.status,
    required this.imageUrls,
    required this.estimatedDurationMinutes,
    required this.estimatedPriceMin,
    required this.estimatedPriceMax,
    required this.technicianFee,
    required this.platformFee,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive =>
      status == 'pending' || status == 'confirmed' || status == 'accepted';

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

    return BookingModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      clientId: data['clientId'] ?? '',
      technicianId: data['technicianId'] ?? '',
      participants: List<String>.from(data['participants'] ?? const []),
      technicianName: data['technicianName'] ?? 'Technician',
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? 'Service',
      scheduledAt: scheduledAt,
      scheduledTimeLabel: data['scheduledTimeLabel'] ?? '',
      description: data['description'] ?? '',
      urgency: data['urgency'] ?? 'Normal',
      status: data['status'] ?? 'pending',
      imageUrls: List<String>.from(data['imageUrls'] ?? const []),
      estimatedDurationMinutes:
          (data['estimatedDurationMinutes'] as num?)?.toInt() ?? 60,
      estimatedPriceMin:
          (data['estimatedPriceMin'] as num?)?.toDouble() ?? 0.0,
      estimatedPriceMax:
          (data['estimatedPriceMax'] as num?)?.toDouble() ?? 0.0,
      technicianFee: (data['technicianFee'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': id,
      'chatId': chatId,
      'participants': participants,
      'clientId': clientId,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'scheduledTimeLabel': scheduledTimeLabel,
      'description': description,
      'urgency': urgency,
      'status': status,
      'imageUrls': imageUrls,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'estimatedPriceMin': estimatedPriceMin,
      'estimatedPriceMax': estimatedPriceMax,
      'technicianFee': technicianFee,
      'platformFee': platformFee,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get humanDate {
    final weekday = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][scheduledAt.weekday - 1];
    return '$weekday, ${scheduledAt.month}/${scheduledAt.day}/${scheduledAt.year}';
  }
}
