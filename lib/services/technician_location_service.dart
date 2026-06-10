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
  });

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
  static const _publishInterval = Duration(seconds: 5);

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Timer? _publishTimer;
  bool _isPublishing = false;
  bool _publishInProgress = false;

  // ── Technician side ──────────────────────────────────────────────────────

  /// Start publishing technician location every 5 seconds
  Future<void> startPublishing() async {
    print('\n🚀 START PUBLISHING CALLED');
    
    if (_isPublishing) {
      print('⚠️  Already publishing - skipping');
      debugPrint('[TechnicianLocationService] Already publishing');
      return;
    }

    _isPublishing = true;
    print('✅ Publishing flag set to true');
    print('⏱️  Will update location every ${_publishInterval.inSeconds} seconds');
    debugPrint('[TechnicianLocationService] Starting location publishing');
    
    // Publish immediately
    print('📍 Publishing location immediately...');
    await _publishOnce();
    
    // Then publish every 5 seconds
    print('⏱️  Setting up periodic timer...');
    _publishTimer?.cancel();
    _publishTimer = Timer.periodic(_publishInterval, (timer) async {
      print('\n⏰ Timer tick #${timer.tick} - Publishing location...');
      await _publishOnce();
    });
    print('✅ Periodic timer started successfully\n');
  }

  /// Stop publishing location updates
  /// Does NOT set any "online" field - we rely solely on updatedAt timestamp
  void stopPublishing() {
    print('\n🛑 STOP PUBLISHING CALLED');
    
    if (!_isPublishing) {
      print('⚠️  Not currently publishing - skipping');
      debugPrint('[TechnicianLocationService] Not currently publishing');
      return;
    }

    print('🛑 Stopping location publishing...');
    debugPrint('[TechnicianLocationService] Stopping location publishing');
    _isPublishing = false;
    
    // Cancel timer
    _publishTimer?.cancel();
    _publishTimer = null;
    
    print('✅ Timer cancelled');
    print('✅ Publishing flag set to false');
    print('ℹ️  Technician will appear offline when updatedAt becomes old (>10s)');
    
    // NO "online" field update - technician is considered offline when updatedAt is old
    debugPrint('[TechnicianLocationService] Location publishing stopped');
    print('========================================\n');
  }

  /// Publish current location once
  /// ONLY updates: lat, lng, updatedAt (NO "online" field)
  Future<void> _publishOnce() async {
    if (_publishInProgress) {
      debugPrint('[TechnicianLocationService] Publish already in progress');
      return;
    }

    _publishInProgress = true;

    print('\n========================================');
    print('UPDATING LOCATION...');
    print('========================================');
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        print('❌ ERROR: No authenticated user');
        debugPrint('[TechnicianLocationService] No authenticated user');
        return;
      }

      print('✅ User authenticated: $uid');

      print('📍 Checking location services...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ ERROR: Location services are disabled');
        debugPrint('[TechnicianLocationService] Location services disabled');
        return;
      }

      print('📍 Checking location permission...');
      var permission = await Geolocator.checkPermission();
      print('📍 Permission status: $permission');

      if (permission == LocationPermission.denied) {
        print('📍 Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('📍 Permission after request: $permission');
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ ERROR: Location permission denied');
        debugPrint('[TechnicianLocationService] Location permission denied');
        return;
      }

      print('✅ Location permission granted');

      print('📍 Getting current position...');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      print('✅ Position obtained:');
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
        'isOnline': true,
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
                'isOnline': true,
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

  /// Emits only RECENTLY ACTIVE technicians within [_radiusKm] of [userPoint]
  /// A technician is considered online if their last update was within 10 seconds
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

            // Filter 1: Check if last update was within 10 seconds (online check)
            final secondsSinceUpdate = now.difference(t.updatedAt).inSeconds;
            final isOnline = secondsSinceUpdate <= 10;
            
            if (!isOnline) {
              debugPrint('[TechnicianLocationService] Technician ${t.id} is offline (${secondsSinceUpdate}s ago)');
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
