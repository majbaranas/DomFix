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
  
  // New Marketplace Fields
  final double? clientLat;
  final double? clientLng;
  final double? technicianEstimatedPrice;
  final String? technicianEstimatedDuration;
  final String? technicianNote;

  // Inspection Workflow Fields
  final double? inspectionFee;
  final String? inspectionMessage;
  final String? preferredVisitDate;
  final String? preferredVisitTime;
  final DateTime? inspectionRequestedAt;
  final DateTime? inspectionAcceptedAt;
  final DateTime? inspectionCompletedAt;

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
    this.clientLat,
    this.clientLng,
    this.technicianEstimatedPrice,
    this.technicianEstimatedDuration,
    this.technicianNote,
    this.inspectionFee,
    this.inspectionMessage,
    this.preferredVisitDate,
    this.preferredVisitTime,
    this.inspectionRequestedAt,
    this.inspectionAcceptedAt,
    this.inspectionCompletedAt,
  });

  String get normalizedStatus => status.toLowerCase().trim();

  bool get isActive {
    return normalizedStatus == 'pending_quote' ||
        normalizedStatus == 'quote_sent' ||
        normalizedStatus == 'pending' ||
        normalizedStatus == 'confirmed' ||
        normalizedStatus == 'accepted' ||
        normalizedStatus == 'on_the_way' ||
        normalizedStatus == 'arrived' ||
        normalizedStatus == 'in_progress' ||
        normalizedStatus == 'in progress' ||
        normalizedStatus == 'completed_pending_confirmation' ||
        normalizedStatus == 'inspection_requested' ||
        normalizedStatus == 'inspection_accepted' ||
        normalizedStatus == 'inspection_completed';
  }

  bool get isInspectionFlow =>
      normalizedStatus == 'inspection_requested' ||
      normalizedStatus == 'inspection_accepted' ||
      normalizedStatus == 'inspection_completed';

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scheduledAt =
        (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
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
      estimatedPriceMin: (data['estimatedPriceMin'] as num?)?.toDouble() ?? 0.0,
      estimatedPriceMax: (data['estimatedPriceMax'] as num?)?.toDouble() ?? 0.0,
      technicianFee: (data['technicianFee'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      updatedAt: updatedAt,
      clientLat: (data['clientLat'] as num?)?.toDouble(),
      clientLng: (data['clientLng'] as num?)?.toDouble(),
      technicianEstimatedPrice: (data['technicianEstimatedPrice'] as num?)?.toDouble(),
      technicianEstimatedDuration: data['technicianEstimatedDuration'] as String?,
      technicianNote: data['technicianNote'] as String?,
      inspectionFee: (data['inspectionFee'] as num?)?.toDouble(),
      inspectionMessage: data['inspectionMessage'] as String?,
      preferredVisitDate: data['preferredVisitDate'] as String?,
      preferredVisitTime: data['preferredVisitTime'] as String?,
      inspectionRequestedAt: (data['inspectionRequestedAt'] as Timestamp?)?.toDate(),
      inspectionAcceptedAt: (data['inspectionAcceptedAt'] as Timestamp?)?.toDate(),
      inspectionCompletedAt: (data['inspectionCompletedAt'] as Timestamp?)?.toDate(),
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
      if (clientLat != null) 'clientLat': clientLat,
      if (clientLng != null) 'clientLng': clientLng,
      if (technicianEstimatedPrice != null) 'technicianEstimatedPrice': technicianEstimatedPrice,
      if (technicianEstimatedDuration != null) 'technicianEstimatedDuration': technicianEstimatedDuration,
      if (technicianNote != null) 'technicianNote': technicianNote,
      if (inspectionFee != null) 'inspectionFee': inspectionFee,
      if (inspectionMessage != null) 'inspectionMessage': inspectionMessage,
      if (preferredVisitDate != null) 'preferredVisitDate': preferredVisitDate,
      if (preferredVisitTime != null) 'preferredVisitTime': preferredVisitTime,
      if (inspectionRequestedAt != null) 'inspectionRequestedAt': Timestamp.fromDate(inspectionRequestedAt!),
      if (inspectionAcceptedAt != null) 'inspectionAcceptedAt': Timestamp.fromDate(inspectionAcceptedAt!),
      if (inspectionCompletedAt != null) 'inspectionCompletedAt': Timestamp.fromDate(inspectionCompletedAt!),
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

  /// Numeric weight for priority-based sorting (higher = more urgent).
  int get priorityWeight => urgencyWeight(urgency);

  /// Maps an urgency label to a numeric weight.
  static int urgencyWeight(String urgency) {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  /// Compare bookings for dashboard ordering:
  /// Emergency first → High → Medium → Low, then by date ascending.
  int compareByPriority(BookingModel other) {
    final priorityCmp = other.priorityWeight.compareTo(priorityWeight);
    if (priorityCmp != 0) return priorityCmp;
    final dateCmp = scheduledAt.compareTo(other.scheduledAt);
    if (dateCmp != 0) return dateCmp;
    return createdAt.compareTo(other.createdAt);
  }
}

