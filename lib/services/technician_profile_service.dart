import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/technician_profile_model.dart';
import '../models/technician_onboarding_data.dart';
import '../models/marketplace_technician.dart';
import 'package:latlong2/latlong.dart';

class TechnicianProfileService {
  static final TechnicianProfileService _instance = TechnicianProfileService._internal();
  factory TechnicianProfileService() => _instance;
  TechnicianProfileService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache to avoid unnecessary reads
  final Map<String, _CachedProfile> _profileCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Save complete onboarding data to Firestore
  /// Splits data between users and technician_profiles collections
  Future<void> saveOnboardingProfile({
    required String uid,
    required String email,
    required TechnicianOnboardingData data,
    required double lat,
    required double lng,
  }) async {
    print('📝 Saving onboarding profile for uid: $uid');
    
    final batch = _firestore.batch();
    
    // 1. Update users collection (basic + public fields)
    final userRef = _firestore.collection('users').doc(uid);
    final userData = {
      'uid': uid,
      'email': email,
      'role': 'technician',
      'fullName': data.fullName ?? 'Technician',
      'profileImage': data.profilePhotoUrl,
      'bio': data.bio,
      'city': data.city,
      'speciality': data.specialties.isNotEmpty ? data.specialties.first : 'Specialist',
      'specialties': data.specialties,
      'lat': lat,
      'lng': lng,
      'isAvailable': data.isAvailable,
      'isOnline': true,
      'onboardingCompleted': true,
      'updated_at': FieldValue.serverTimestamp(),
    };
    batch.set(userRef, userData, SetOptions(merge: true));
    
    // 2. Create/update technician_profiles collection (extended data)
    final profileRef = _firestore.collection('technician_profiles').doc(uid);
    final profileCompletion = TechnicianProfileModel.calculateProfileCompletion(
      userData,
      {
        'specialties': data.specialties,
        'customSkills': data.customSkills,
        'yearsOfExperience': data.yearsOfExperience,
        'certificationUrls': data.certificationUrls,
        'portfolioUrls': data.portfolioUrls,
        'availableDays': data.availableDays,
        'isPhoneVerified': data.isPhoneVerified,
        'isIdentityVerified': data.identityDocumentUrl != null,
        'identityDocumentUrl': data.identityDocumentUrl,
        'phoneNumber': data.phoneNumber,
      },
    );
    
    final profileData = {
      'specialties': data.specialties,
      'customSkills': data.customSkills,
      'primarySpecialty': data.specialties.isNotEmpty ? data.specialties.first : 'Specialist',
      'yearsOfExperience': data.yearsOfExperience,
      'certificationUrls': data.certificationUrls,
      'portfolioUrls': data.portfolioUrls,
      'isAvailable': data.isAvailable,
      'availableDays': data.availableDays,
      'workingHours': {
        'startHour': data.startHour,
        'startMinute': data.startMinute,
        'endHour': data.endHour,
        'endMinute': data.endMinute,
      },
      'serviceRadiusMiles': data.serviceRadiusMiles,
      'lat': lat,
      'lng': lng,
      if (data.age != null) 'age': data.age,
      if (data.city != null) 'city': data.city,
      if (data.bio != null) 'bio': data.bio,
      if (data.profilePhotoUrl != null) 'profilePhotoUrl': data.profilePhotoUrl,
      if (data.identityDocumentUrl != null) 'identityDocumentUrl': data.identityDocumentUrl,
      if (data.phoneNumber != null) 'phoneNumber': data.phoneNumber,
      'isPhoneVerified': data.isPhoneVerified,
      'isIdentityVerified': data.identityDocumentUrl != null,
      'profileCompletionScore': profileCompletion,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(profileRef, profileData, SetOptions(merge: true));
    
    // 3. Initialize technician_stats if not exists
    final statsRef = _firestore.collection('technician_stats').doc(uid);
    final statsData = {
      'technicianId': uid,
      'averageRating': 0.0,
      'totalReviews': 0,
      'completedJobs': 0,
      'rankScore': profileCompletion, // Initial rank based on profile completion
      'reviewQualityScore': 100.0,
      'profileCompletionBonus': profileCompletion,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    batch.set(statsRef, statsData, SetOptions(merge: true));
    
    await batch.commit();
    print('✅ Onboarding profile saved successfully');
    
    // Invalidate cache
    _profileCache.remove(uid);
  }

  /// Get full technician profile (cached)
  Future<TechnicianProfileModel?> getProfile(String technicianId) async {
    print('🔍 Fetching profile for: $technicianId');
    
    // Check cache first
    final cached = _profileCache[technicianId];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      print('✅ Using cached profile');
      return cached.profile;
    }
    
    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _firestore.collection('users').doc(technicianId).get(),
        _firestore.collection('technician_profiles').doc(technicianId).get(),
        _firestore.collection('technician_stats').doc(technicianId).get(),
      ]);
      
      final userDoc = results[0];
      final profileDoc = results[1];
      final statsDoc = results[2];
      
      if (!userDoc.exists) {
        print('❌ User document not found');
        return null;
      }
      
      final userData = userDoc.data()!;
      final profileData = profileDoc.exists ? profileDoc.data() : null;
      final statsData = statsDoc.exists ? statsDoc.data() : null;
      
      final profile = TechnicianProfileModel.fromFirestore(
        technicianId,
        userData,
        profileData,
        statsData,
      );
      
      // Cache the result
      _profileCache[technicianId] = _CachedProfile(profile, DateTime.now());
      
      print('✅ Profile loaded: ${profile.fullName}, completion: ${profile.profileCompletionScore.toStringAsFixed(0)}%');
      return profile;
    } catch (e, stackTrace) {
      print('❌ Error fetching profile: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Stream profile updates in real-time
  Stream<TechnicianProfileModel?> streamProfile(String technicianId) {
    return _firestore
        .collection('users')
        .doc(technicianId)
        .snapshots()
        .asyncMap((userSnap) async {
      if (!userSnap.exists) return null;
      
      final profileSnap = await _firestore
          .collection('technician_profiles')
          .doc(technicianId)
          .get();
      final statsSnap = await _firestore
          .collection('technician_stats')
          .doc(technicianId)
          .get();
      
      return TechnicianProfileModel.fromFirestore(
        technicianId,
        userSnap.data()!,
        profileSnap.exists ? profileSnap.data() : null,
        statsSnap.exists ? statsSnap.data() : null,
      );
    });
  }

  /// Update profile fields
  Future<void> updateProfile({
    required String uid,
    String? fullName,
    String? bio,
    String? profilePhotoUrl,
    String? city,
    List<String>? specialties,
    bool? isAvailable,
    Map<String, dynamic>? workingHours,
  }) async {
    print('📝 Updating profile for: $uid');
    
    final batch = _firestore.batch();
    
    // Update users collection
    final userUpdates = <String, dynamic>{};
    if (fullName != null) userUpdates['fullName'] = fullName;
    if (bio != null) userUpdates['bio'] = bio;
    if (profilePhotoUrl != null) userUpdates['profileImage'] = profilePhotoUrl;
    if (city != null) userUpdates['city'] = city;
    if (isAvailable != null) userUpdates['isAvailable'] = isAvailable;
    if (specialties != null && specialties.isNotEmpty) {
      userUpdates['speciality'] = specialties.first;
    }
    userUpdates['updated_at'] = FieldValue.serverTimestamp();
    
    if (userUpdates.isNotEmpty) {
      batch.update(_firestore.collection('users').doc(uid), userUpdates);
    }
    
    // Update technician_profiles collection
    final profileUpdates = <String, dynamic>{};
    if (specialties != null) {
      profileUpdates['specialties'] = specialties;
      profileUpdates['primarySpecialty'] = specialties.isNotEmpty ? specialties.first : 'Technician';
    }
    if (workingHours != null) profileUpdates['workingHours'] = workingHours;
    if (isAvailable != null) profileUpdates['isAvailable'] = isAvailable;
    profileUpdates['updatedAt'] = FieldValue.serverTimestamp();
    
    if (profileUpdates.isNotEmpty) {
      batch.set(
        _firestore.collection('technician_profiles').doc(uid),
        profileUpdates,
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
    
    // Recalculate profile completion score
    await _recalculateProfileCompletion(uid);
    
    // Invalidate cache
    _profileCache.remove(uid);
    
    print('✅ Profile updated');
  }

  /// Recalculate and update profile completion score
  Future<void> _recalculateProfileCompletion(String uid) async {
    try {
      final userSnap = await _firestore.collection('users').doc(uid).get();
      final profileSnap = await _firestore.collection('technician_profiles').doc(uid).get();
      
      if (!userSnap.exists) return;
      
      final userData = userSnap.data()!;
      final profileData = profileSnap.exists ? profileSnap.data() : null;
      
      final completionScore = TechnicianProfileModel.calculateProfileCompletion(
        userData,
        profileData,
      );
      
      // Update both collections
      final batch = _firestore.batch();
      
      batch.set(
        _firestore.collection('technician_profiles').doc(uid),
        {'profileCompletionScore': completionScore, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      
      // Recalculate full rankScore including all factors
      final statsSnap = await _firestore.collection('technician_stats').doc(uid).get();
      final statsData = statsSnap.exists ? statsSnap.data()! : <String, dynamic>{};
      
      final averageRating = (statsData['averageRating'] as num?)?.toDouble() ?? 0.0;
      final totalReviews = (statsData['totalReviews'] as num?)?.toInt() ?? 0;
      final completedJobs = (statsData['completedJobs'] as num?)?.toInt() ?? 0;
      final reviewQualityScore = (statsData['reviewQualityScore'] as num?)?.toDouble() ?? 0.0;
      
      // Enhanced ranking formula with profile completion bonus
      final ratingWeight = averageRating * 100;
      final trustWeight = (totalReviews > 50 ? 50 : totalReviews) * 2;
      final volumeWeight = (completedJobs > 100 ? 100 : completedJobs).toDouble();
      final qualityWeight = reviewQualityScore * 10;
      final profileWeight = completionScore * 0.5; // Profile completion contributes up to 50 points
      
      final rankScore = double.parse(
        (ratingWeight + trustWeight + volumeWeight + qualityWeight + profileWeight).toStringAsFixed(3),
      );
      
      // Update rankScore in technician_stats
      batch.set(
        _firestore.collection('technician_stats').doc(uid),
        {
          'profileCompletionBonus': completionScore,
          'rankScore': rankScore,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      
      // Update users collection for backward compatibility
      batch.set(
        _firestore.collection('users').doc(uid),
        {
          'rankScore': rankScore,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      
      await batch.commit();
      
      print('✅ Profile completion recalculated: $completionScore%');
      print('✅ Rank score updated: $rankScore');
    } catch (e) {
      print('❌ Error recalculating profile completion: $e');
    }
  }

  /// Query technicians with filters (for search/map)
  Future<List<TechnicianProfileModel>> queryTechnicians({
    GeoPoint? nearLocation,
    double? radiusKm,
    List<String>? specialties,
    double? minRating,
    int limit = 20,
  }) async {
    print('🔍 Querying technicians...');
    
    Query query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('onboardingCompleted', isEqualTo: true);
    
    if (minRating != null) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }
    
    query = query.limit(limit);
    
    final snapshot = await query.get();
    
    final profiles = <TechnicianProfileModel>[];
    
    for (final doc in snapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;
      
      // Fetch extended profile and stats
      final profileSnap = await _firestore.collection('technician_profiles').doc(doc.id).get();
      final statsSnap = await _firestore.collection('technician_stats').doc(doc.id).get();
      
      final profile = TechnicianProfileModel.fromFirestore(
        doc.id,
        userData,
        profileSnap.exists ? profileSnap.data() : null,
        statsSnap.exists ? statsSnap.data() : null,
      );
      
      // Apply filters
      if (specialties != null && specialties.isNotEmpty) {
        if (!profile.specialties.any((s) => specialties.contains(s))) {
          continue;
        }
      }
      
      // Apply location filter if provided
      if (nearLocation != null && radiusKm != null && profile.location != null) {
        final distance = _calculateDistance(
          nearLocation.latitude,
          nearLocation.longitude,
          profile.location!.latitude,
          profile.location!.longitude,
        );
        if (distance > radiusKm) continue;
      }
      
      profiles.add(profile);
    }
    
    // Sort by rankScore (includes profile completion bonus)
    profiles.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    
    print('✅ Found ${profiles.length} technicians');
    return profiles;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        0.5 * (lat2 - lat1) * p +
        0.5 * (1 + (lat1 * p)) * (1 + (lat2 * p)) * (1 - (lon2 - lon1) * p);
    return 12742 * 0.5 * a; // 2 * R * asin(sqrt(a)), R = 6371 km
  }

  /// Real-time stream of all available marketplace technicians
  /// Combines the rankScore with a dynamic distance penalty
  Stream<List<MarketplaceTechnician>> watchMarketplaceTechnicians({LatLng? userLocation}) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('isAvailable', isEqualTo: true)
        // Note: we can't do .orderBy('rankScore', descending: true) here easily 
        // without a composite index. We'll do it client-side since Spark plan
        // users often avoid maintaining multiple composite indexes.
        .snapshots()
        .map((snap) {
          final techs = snap.docs
              .map((doc) => MarketplaceTechnician.fromDoc(doc))
              .toList();
          
          for (final t in techs) {
            if (userLocation != null) {
              t.calculateDistance(userLocation);
            }
          }
          
          // Sort by a combination of rankScore and distance penalty
          techs.sort((a, b) {
            double scoreA = a.rankScore;
            double scoreB = b.rankScore;
            
            // Apply slight distance penalty if location is known
            if (userLocation != null) {
              if (a.distanceKm < double.infinity) scoreA -= a.distanceKm * 0.5;
              if (b.distanceKm < double.infinity) scoreB -= b.distanceKm * 0.5;
            }
            
            return scoreB.compareTo(scoreA); // Descending order
          });
          
          return techs;
        });
  }

  /// Clear cache for a specific technician
  void invalidateCache(String technicianId) {
    _profileCache.remove(technicianId);
  }

  /// Clear all cached profiles
  void clearCache() {
    _profileCache.clear();
  }
}

class _CachedProfile {
  final TechnicianProfileModel profile;
  final DateTime timestamp;

  _CachedProfile(this.profile, this.timestamp);
}
