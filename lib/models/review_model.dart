import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicianReview {
  const TechnicianReview({
    required this.id,
    required this.bookingId,
    this.jobId,
    required this.clientId,
    required this.technicianId,
    required this.rating,
    required this.comment,
    required this.serviceName,
    required this.createdAt,
    this.clientName,
    this.clientPhotoUrl,
  });

  final String id;
  final String bookingId;
  final String? jobId;
  final String clientId;
  final String technicianId;
  final int rating;
  final String comment;
  final String serviceName;
  final DateTime createdAt;
  final String? clientName;
  final String? clientPhotoUrl;

  factory TechnicianReview.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TechnicianReview(
      id: doc.id,
      bookingId: (data['bookingId'] ?? doc.id).toString(),
      jobId: data['jobId']?.toString(),
      clientId: (data['clientId'] ?? '').toString(),
      technicianId: (data['technicianId'] ?? '').toString(),
      rating: (data['rating'] as num?)?.toInt().clamp(1, 5) ?? 5,
      comment: (data['comment'] ?? '').toString(),
      serviceName: (data['serviceName'] ?? 'Service').toString(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientName: data['clientName']?.toString(),
      clientPhotoUrl: data['clientPhotoUrl']?.toString(),
    );
  }
}

class CompletedJobPhoto {
  const CompletedJobPhoto({
    required this.id,
    required this.bookingId,
    this.jobId,
    required this.technicianId,
    required this.clientId,
    required this.imageUrl,
    required this.kind,
    required this.createdAt,
    required this.serviceName,
  });

  final String id;
  final String bookingId;
  final String? jobId;
  final String technicianId;
  final String clientId;
  final String imageUrl;
  final String kind;
  final DateTime createdAt;
  final String serviceName;

  factory CompletedJobPhoto.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CompletedJobPhoto(
      id: doc.id,
      bookingId: (data['bookingId'] ?? '').toString(),
      jobId: data['jobId']?.toString(),
      technicianId: (data['technicianId'] ?? '').toString(),
      clientId: (data['clientId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      kind: (data['kind'] ?? 'result').toString(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceName: (data['serviceName'] ?? 'Completed work').toString(),
    );
  }
}

class TechnicianStats {
  const TechnicianStats({
    required this.technicianId,
    required this.averageRating,
    required this.totalReviews,
    required this.completedJobs,
    required this.ratingSum,
    required this.reviewQualityScore,
    required this.rankScore,
  });

  final String technicianId;
  final double averageRating;
  final int totalReviews;
  final int completedJobs;
  final int ratingSum;
  final double reviewQualityScore;
  final double rankScore;

  factory TechnicianStats.empty(String technicianId) {
    return TechnicianStats(
      technicianId: technicianId,
      averageRating: 0,
      totalReviews: 0,
      completedJobs: 0,
      ratingSum: 0,
      reviewQualityScore: 0,
      rankScore: 0,
    );
  }

  factory TechnicianStats.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TechnicianStats(
      technicianId: doc.id,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (data['totalReviews'] as num?)?.toInt() ?? 0,
      completedJobs: (data['completedJobs'] as num?)?.toInt() ?? 0,
      ratingSum: (data['ratingSum'] as num?)?.toInt() ?? 0,
      reviewQualityScore:
          (data['reviewQualityScore'] as num?)?.toDouble() ?? 0,
      rankScore: (data['rankScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
