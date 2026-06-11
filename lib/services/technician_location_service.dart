import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'technician_ranking_service.dart';
import '../utils/technician_specialty_catalog.dart';

class TechnicianLocation {
  const TechnicianLocation({
    required this.id,
    required this.point,
    required this.updatedAt,
    this.name,
    this.fullName,
    this.speciality,
    this.specialties = const [],
    this.servicesProvided = const [],
    this.profileImage,
    this.isOnline = true,
    this.liveStatus = 'offline',
    DateTime? lastSeen,
    this.role,
    this.rankScore = 0.0,
    this.averageRating = 0.0,
    this.completedJobs = 0,
    this.reviewCount = 0,
    this.profileCompletionScore = 0.0,
    this.responseSpeedScore = 0.0,
    this.availabilityScore = 0.0,
    this.activityScore = 0.0,
    this.onboardingCompleted = true,
    this.profileCompleted = true,
    this.availabilityEnabled = true,
    this.activeAccount = true,
  }) : lastSeen = lastSeen ?? updatedAt;

  final String id;
  final LatLng point;
  final DateTime updatedAt;
  final String? name;
  final String? fullName;
  final String? speciality;
  final List<String> specialties;
  final List<String> servicesProvided;
  final String? profileImage;
  final bool isOnline;
  final String liveStatus;
  final DateTime lastSeen;
  final String? role;
  final double rankScore;
  final double averageRating;
  final int completedJobs;
  final int reviewCount;
  final double profileCompletionScore;
  final double responseSpeedScore;
  final double availabilityScore;
  final double activityScore;
  final bool onboardingCompleted;
  final bool profileCompleted;
  final bool availabilityEnabled;
  final bool activeAccount;

  factory TechnicianLocation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data();
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid technician document data');
    }

    final point = _readPoint(data);
    final updatedAt = _readUpdatedAt(data);
    final lastSeen = _readLastSeen(data) ?? updatedAt;

    return TechnicianLocation(
      id: doc.id,
      point: point,
      updatedAt: updatedAt,
      name: _readString(data['fullName'] ?? data['name'] ?? data['displayName']),
      fullName: _readString(data['fullName'] ?? data['name'] ?? data['displayName']),
      speciality: _readString(data['speciality'] ?? data['specialty'] ?? data['job']),
      specialties: _readList(data['specialties'] ?? data['servicesProvided']),
      servicesProvided: _readList(data['servicesProvided'] ?? data['specialties']),
      profileImage: _readString(data['profileImage'] ?? data['profilePhotoUrl'] ?? data['photoUrl']),
      isOnline: data['isOnline'] != false,
      liveStatus: _readString(data['liveStatus']) ?? 'offline',
      lastSeen: lastSeen,
      role: _readString(data['role']),
      rankScore: _readDouble(data['rankScore']),
      averageRating: _readDouble(data['averageRating'] ?? data['rating']),
      completedJobs: _readInt(data['completedJobs'] ?? data['jobsCompleted']),
      reviewCount: _readInt(data['reviewCount'] ?? data['totalReviews']),
      profileCompletionScore: _readDouble(data['profileCompletionScore'] ?? data['profileCompletenessScore']),
      responseSpeedScore: _readDouble(data['responseSpeedScore']),
      availabilityScore: _readDouble(data['availabilityScore']),
      activityScore: _readDouble(data['activityScore']),
      onboardingCompleted: data['onboardingCompleted'] != false,
      profileCompleted: data['profileCompleted'] != false,
      availabilityEnabled: data['availabilityEnabled'] != false,
      activeAccount: data['activeAccount'] != false,
    );
  }

  static LatLng _readPoint(Map<String, dynamic> data) {
    final dynamic location = data['location'];
    final dynamic latRaw = data['lat'] ??
        data['latitude'] ??
        (location is Map<String, dynamic>
            ? location['lat'] ?? location['latitude']
            : null);
    final dynamic lngRaw = data['lng'] ??
        data['longitude'] ??
        (location is Map<String, dynamic>
            ? location['lng'] ?? location['longitude']
            : null);

    if (latRaw is num && lngRaw is num) {
      return LatLng(latRaw.toDouble(), lngRaw.toDouble());
    }

    throw const FormatException('Missing latitude or longitude');
  }

  static DateTime _readUpdatedAt(Map<String, dynamic> data) {
    final dynamic raw = data['updatedAt'] ?? data['updated_at'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return DateTime.now();
  }

  static DateTime? _readLastSeen(Map<String, dynamic> data) {
    final dynamic raw = data['lastSeen'];
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return null;
  }

  static String? _readString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _readList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class TechnicianLocationService {
  static const _collection = 'technician_locations';
  static const _radiusKm = 10.0;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  bool _publishInProgress = false;

  // ── Technician side ──────────────────────────────────────────────────────

  /// Start listening to location changes and update Firestore when moved
  Future<void> startLocationTracking() async {
    print('\n🚀 START LOCATION TRACKING CALLED');
    
    if (_isTracking) {
      debugPrint('[TechnicianLocationService] Already tracking location');
      return;
    }

    print('📍 Checking location permission...');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[TechnicianLocationService] Location permission denied');
      return;
    }

    _isTracking = true;
    
    // Setup stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Update when moved 100 meters
      ),
    ).listen((Position position) {
      _publishLocation(position);
    });
    
    // Also update status to online instantly
    await updateLiveStatus('online');
  }

  /// Stop listening to location changes
  Future<void> stopLocationTracking() async {
    print('\n🛑 STOP LOCATION TRACKING CALLED');
    
    if (!_isTracking) return;

    _isTracking = false;
    await _positionStream?.cancel();
    _positionStream = null;
    
    await updateLiveStatus('offline');
  }

  /// Explicitly update the live status (online, busy, on_job, offline)
  Future<void> updateLiveStatus(String status) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final payload = {
        'liveStatus': status,
        'lastSeen': FieldValue.serverTimestamp(),
      };
      
      await Future.wait([
        _firestore.collection(_collection).doc(uid).set(payload, SetOptions(merge: true)),
        _firestore.collection('users').doc(uid).set(payload, SetOptions(merge: true)),
      ]);
      debugPrint('[TechnicianLocationService] Status updated to: $status');
    } catch (e) {
      debugPrint('[TechnicianLocationService] Error updating status: $e');
    }
  }

  /// Publish given location
  Future<void> _publishLocation(Position pos) async {
    if (_publishInProgress) return;
    _publishInProgress = true;

    print('\n========================================');
    print('UPDATING LOCATION...');
    print('========================================');
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      print('✅ User authenticated: $uid');
      print('   Latitude: ${pos.latitude}');
      print('   Longitude: ${pos.longitude}');
      print('   Accuracy: ${pos.accuracy}m');
      print('   Timestamp: ${DateTime.now()}');

      final profileFuture = Future.wait([
        _firestore.collection('users').doc(uid).get(),
        _firestore.collection('technician_profiles').doc(uid).get(),
        _firestore.collection('technician_stats').doc(uid).get(),
      ]);
      final profileResults = await profileFuture;
      final userData = profileResults[0].data() ?? <String, dynamic>{};
      final profileData = profileResults[1].data() ?? <String, dynamic>{};
      final statsData = profileResults[2].data() ?? <String, dynamic>{};

      final specialties = _mergeSpecialties(
        userData['specialties'],
        profileData['specialties'],
        profileData['servicesProvided'],
      );
      final primarySpecialty = (profileData['primarySpecialty'] ??
              userData['speciality'] ??
              userData['specialty'] ??
              (specialties.isNotEmpty ? specialties.first : 'Specialist'))
          .toString();
      final fullName = (userData['fullName'] ?? userData['name'] ?? 'Technician')
          .toString();
      final profileImage = (userData['profileImage'] ?? profileData['profilePhotoUrl'] ?? '')
          .toString();
      final averageRating = (statsData['averageRating'] as num?)?.toDouble() ?? (userData['averageRating'] as num?)?.toDouble() ?? (userData['rating'] as num?)?.toDouble() ?? 0.0;
      final completedJobs = (statsData['completedJobs'] as num?)?.toInt() ?? (userData['jobsCompleted'] as num?)?.toInt() ?? 0;
      final rankScore = (statsData['rankScore'] as num?)?.toDouble() ?? (userData['rankScore'] as num?)?.toDouble() ?? 0.0;
      final reviewCount = (statsData['totalReviews'] as num?)?.toInt() ?? (statsData['reviewCount'] as num?)?.toInt() ?? (userData['reviewCount'] as num?)?.toInt() ?? 0;
      final profileCompletionScore = (statsData['profileCompletenessScore'] as num?)?.toDouble() ??
          (statsData['profileCompletionScore'] as num?)?.toDouble() ??
          (userData['profileCompletionScore'] as num?)?.toDouble() ??
          0.0;
      final responseSpeedScore = (statsData['responseSpeedScore'] as num?)?.toDouble() ?? 0.0;
      final availabilityScore = (statsData['availabilityScore'] as num?)?.toDouble() ?? 0.0;
      final activityScore = (statsData['activityScore'] as num?)?.toDouble() ?? 0.0;
      final availabilityEnabled = userData['availabilityEnabled'] ??
          profileData['availabilityEnabled'] ??
          statsData['availabilityEnabled'] ??
          userData['isAvailable'] ??
          profileData['isAvailable'] ??
          true;
      final onboardingCompleted = userData['onboardingCompleted'] ?? profileData['onboardingCompleted'] ?? true;
      final profileCompleted = userData['profileCompleted'] ?? profileData['profileCompleted'] ?? true;
      final activeAccount = userData['activeAccount'] ??
          (userData['accountStatus'] == 'active') ??
          profileData['activeAccount'] ??
          true;

      final locationPayload = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location': {
          'lat': pos.latitude,
          'lng': pos.longitude,
        },
        'fullName': fullName,
        'name': fullName,
        'displayName': fullName,
        'profileImage': profileImage,
        'speciality': primarySpecialty,
        'specialties': specialties,
        'servicesProvided': specialties,
        'averageRating': averageRating,
        'rating': averageRating,
        'completedJobs': completedJobs,
        'jobsCompleted': completedJobs,
        'reviewCount': reviewCount,
        'totalReviews': reviewCount,
        'rankScore': rankScore,
        'profileCompletionScore': profileCompletionScore,
        'profileCompletenessScore': profileCompletionScore,
        'responseSpeedScore': responseSpeedScore,
        'availabilityScore': availabilityScore,
        'activityScore': activityScore,
        'onboardingCompleted': onboardingCompleted == true,
        'profileCompleted': profileCompleted == true,
        'availabilityEnabled': availabilityEnabled == true,
        'activeAccount': activeAccount == true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'role': 'technician',
      };

      print('🔥 Updating Firestore...');
      await Future.wait([
        _firestore.collection(_collection).doc(uid).set(
              locationPayload,
              SetOptions(merge: true),
            ),
        _firestore.collection('users').doc(uid).set(
              {
                'lat': pos.latitude,
                'lng': pos.longitude,
                'latitude': pos.latitude,
                'longitude': pos.longitude,
                'location': {
                  'lat': pos.latitude,
                  'lng': pos.longitude,
                },
                'fullName': fullName,
                'profileImage': profileImage,
                'speciality': primarySpecialty,
                'specialties': specialties,
                'servicesProvided': specialties,
                'averageRating': averageRating,
                'rating': averageRating,
                'completedJobs': completedJobs,
                'jobsCompleted': completedJobs,
                'reviewCount': reviewCount,
                'totalReviews': reviewCount,
                'rankScore': rankScore,
                'profileCompletionScore': profileCompletionScore,
                'profileCompletenessScore': profileCompletionScore,
                'responseSpeedScore': responseSpeedScore,
                'availabilityScore': availabilityScore,
                'activityScore': activityScore,
                'onboardingCompleted': onboardingCompleted == true,
                'profileCompleted': profileCompleted == true,
                'availabilityEnabled': availabilityEnabled == true,
                'activeAccount': activeAccount == true,
                'updatedAt': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
                'lastSeen': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            ),
      ]);

      print('✅ Firestore updated successfully!');
      print('   Collection: $_collection');
      print('   Document ID: $uid');
      print(
        '   Data: {lat: ${pos.latitude}, lng: ${pos.longitude}, updatedAt: serverTimestamp}',
      );
      print('========================================\n');

      debugPrint(
        '[TechnicianLocationService] Location published: (${pos.latitude}, ${pos.longitude})',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR publishing location:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('========================================\n');
      debugPrint('[TechnicianLocationService] Error publishing location: $e');
    } finally {
      _publishInProgress = false;
    }
  }

  // ── User side ────────────────────────────────────────────────────────────

  /// Emits only active technicians within [_radiusKm] of [userPoint]
  /// A technician is considered offline if liveStatus == 'offline' or lastSeen > 120 seconds ago and liveStatus == 'online'
  /// Results are sorted by rankScore DESC (best technicians first)
  /// This eliminates "ghost" technicians who closed their app
  Stream<List<TechnicianLocation>> nearbyStream(
    LatLng userPoint, {
    double radiusKm = _radiusKm,
  }) {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final techs = snap.docs
          .map((doc) {
            try {
              return TechnicianLocation.fromDoc(doc);
            } catch (e) {
              debugPrint('[TechnicianLocationService] Error parsing doc ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TechnicianLocation>() // Filter out nulls
          .where((t) {
            if (t.role != null && t.role != 'technician') {
              debugPrint(
                '[TechnicianLocationService] Technician ${t.id} skipped because role=${t.role}',
              );
              return false;
            }

            if (!t.activeAccount || !t.onboardingCompleted || !t.profileCompleted || !t.availabilityEnabled) {
              debugPrint(
                '[TechnicianLocationService] Technician ${t.id} skipped because publishability flags are false',
              );
              return false;
            }

            // Filter 1: Check online status using new Phase 1 logic
            final secondsSinceSeen = now.difference(t.lastSeen).inSeconds;
            bool isOnline = true;
            if (t.liveStatus == 'offline') {
              isOnline = false;
            } else if (t.liveStatus == 'online' && secondsSinceSeen > 120) {
              // Ghost protection: only 'online' state times out quickly (2 minutes).
              // 'busy' or 'on_job' states can persist longer as they don't depend on foreground app as much.
              isOnline = false;
            }
            
            if (!isOnline) {
              debugPrint('[TechnicianLocationService] Technician ${t.id} is offline (status: ${t.liveStatus}, seen ${secondsSinceSeen}s ago)');
              return false;
            }
            
            // Filter 2: Check if within radius
            final distance = _distanceKm(userPoint, t.point);
            final isNearby = distance <= radiusKm;

            if (!isNearby) {
              debugPrint('[TechnicianLocationService] Technician ${t.id} is too far (${distance.toStringAsFixed(1)} km)');
              return false;
            }
            
            return true;
          })
          .toList();
      
      // Sort by rankScore DESC (highest ranked first)
      // Technicians with more reviews, higher ratings, and more completed jobs appear first
      techs.sort((a, b) {
        final scoreA = a.rankScore + TechnicianRankingService.freshnessBonus(a.updatedAt);
        final scoreB = b.rankScore + TechnicianRankingService.freshnessBonus(b.updatedAt);
        return scoreB.compareTo(scoreA);
      });
      
      return techs;
    });
  }

  static double distanceKmPublic(LatLng a, LatLng b) => _distanceKm(a, b);

  List<String> _mergeSpecialties(dynamic a, dynamic b, dynamic c) {
    final values = <String>{};

    void addAll(dynamic source) {
      if (source is! List) return;
      for (final item in source) {
        final value = TechnicianSpecialtyCatalog.normalize(item.toString());
        if (value != null && value.isNotEmpty) {
          values.add(value);
        }
      }
    }

    addAll(a);
    addAll(b);
    addAll(c);
    return values.toList();
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  static double _rad(double deg) => deg * pi / 180;
}
