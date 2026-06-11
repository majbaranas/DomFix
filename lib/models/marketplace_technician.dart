import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../utils/technician_specialty_catalog.dart';

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
  final String liveStatus;
  final DateTime lastSeen;
  
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
    this.liveStatus = 'offline',
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? updatedAt;

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

    // Parse lastSeen
    DateTime lastSeen = upAt;
    final rawSeen = data['lastSeen'];
    if (rawSeen is Timestamp) lastSeen = rawSeen.toDate();
    else if (rawSeen is int) lastSeen = DateTime.fromMillisecondsSinceEpoch(rawSeen);

    // Safely parse numbers from Firestore
    double _parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int _parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    // Fallback for fullName
    String _parseName() {
      if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) return data['fullName'];
      if (data['name'] != null && data['name'].toString().isNotEmpty) return data['name'];
      if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) return data['displayName'];
      if (data['firstName'] != null) {
        final last = data['lastName'] ?? '';
        return '${data['firstName']} $last'.trim();
      }
      return 'Technician';
    }

    // Fallback for speciality
    String _parseSpeciality() {
      final normalizedSpeciality = TechnicianSpecialtyCatalog.normalize(
        data['speciality']?.toString() ??
            data['specialty']?.toString() ??
            data['primarySpecialty']?.toString(),
      );
      if (normalizedSpeciality != null) return normalizedSpeciality;
      
      final specs = data['specialties'];
      if (specs is List && specs.isNotEmpty) {
        final normalizedList = TechnicianSpecialtyCatalog.normalizeList(
          specs.map((e) => e.toString()),
        );
        if (normalizedList.isNotEmpty) return normalizedList.first;
      }
      
      return 'Specialist';
    }

    return MarketplaceTechnician(
      id: doc.id,
      fullName: _parseName(),
      profileImage: data['profileImage'] ?? data['profilePhotoUrl'] ?? data['photoUrl'],
      speciality: _parseSpeciality(),
      specialties: TechnicianSpecialtyCatalog.normalizeList(
        (data['specialties'] as List<dynamic>?)?.map((e) => e.toString()) ?? const <String>[],
      ),
      rating: _parseDouble(data['averageRating'] ?? data['rating']),
      reviewCount: _parseInt(data['reviewCount'] ?? data['totalReviews']),
      jobsCompleted: _parseInt(data['jobsCompleted'] ?? data['completedJobs']),
      rankScore: _parseDouble(data['rankScore']),
      isAvailable: data['isAvailable'] ?? data['availabilityEnabled'] ?? true,
      updatedAt: upAt,
      location: point,
      liveStatus: data['liveStatus']?.toString() ?? 'offline',
      lastSeen: lastSeen,
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
    // Treat as offline if the explicitly set status is offline
    if (liveStatus == 'offline') return false;
    
    // Ghost protection: if lastSeen is older than 2 minutes, treat as offline
    // unless they are explicitly busy or on_job (which might not update location as often)
    if (liveStatus == 'online' && DateTime.now().difference(lastSeen).inSeconds > 120) {
      return false;
    }
    
    return true;
  }
}
