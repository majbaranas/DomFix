import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class MarketplaceTechnician {
  final String id;
  final String fullName;
  final String? profileImage;
  final String speciality;
  final List<String> specialties;
  final double rating;
  final int reviewCount;
  final int jobsCompleted;
  final double rankScore;
  final bool isAvailable;
  final DateTime updatedAt;
  final LatLng? location;
  
  // Calculated fields
  double distanceKm = 0.0;

  MarketplaceTechnician({
    required this.id,
    required this.fullName,
    this.profileImage,
    required this.speciality,
    this.specialties = const [],
    required this.rating,
    required this.reviewCount,
    required this.jobsCompleted,
    required this.rankScore,
    required this.isAvailable,
    required this.updatedAt,
    this.location,
  });

  factory MarketplaceTechnician.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Parse location
    LatLng? point;
    final lat = data['lat'] ?? data['latitude'];
    final lng = data['lng'] ?? data['longitude'];
    if (lat is num && lng is num) {
      point = LatLng(lat.toDouble(), lng.toDouble());
    } else if (data['location'] is Map) {
      final loc = data['location'] as Map;
      final mLat = loc['lat'] ?? loc['latitude'];
      final mLng = loc['lng'] ?? loc['longitude'];
      if (mLat is num && mLng is num) {
        point = LatLng(mLat.toDouble(), mLng.toDouble());
      }
    }

    // Parse updatedAt
    DateTime upAt = DateTime.now();
    final rawUp = data['updated_at'] ?? data['updatedAt'];
    if (rawUp is Timestamp) upAt = rawUp.toDate();
    else if (rawUp is int) upAt = DateTime.fromMillisecondsSinceEpoch(rawUp);

    return MarketplaceTechnician(
      id: doc.id,
      fullName: data['fullName'] ?? data['name'] ?? 'Technician',
      profileImage: data['profileImage'] ?? data['photoUrl'],
      speciality: data['speciality'] ?? data['primarySpecialty'] ?? 'Specialist',
      specialties: (data['specialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (data['averageRating'] ?? data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] ?? data['totalReviews'] as num?)?.toInt() ?? 0,
      jobsCompleted: (data['jobsCompleted'] ?? data['completedJobs'] as num?)?.toInt() ?? 0,
      rankScore: (data['rankScore'] as num?)?.toDouble() ?? 0.0,
      isAvailable: data['isAvailable'] ?? true,
      updatedAt: upAt,
      location: point,
    );
  }

  /// Calculates the distance from a given point and updates `distanceKm`
  void calculateDistance(LatLng from) {
    if (location == null) {
      distanceKm = double.infinity;
      return;
    }
    distanceKm = _distanceKm(from, location!);
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  bool get isOnline {
    // If updated within last 10 seconds, consider them "Live" 
    // Usually means the app is open and location is publishing
    return DateTime.now().difference(updatedAt).inSeconds <= 10;
  }
}
