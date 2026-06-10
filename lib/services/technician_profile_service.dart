import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/technician_profile_model.dart';
import '../models/technician_onboarding_data.dart';
import '../models/marketplace_technician.dart';
import 'technician_ranking_service.dart';
import '../utils/technician_specialty_catalog.dart';
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
    double? lat,
    double? lng,
  }) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUid = authUid ?? uid;
    if (authUid != null && authUid != uid) {
      debugPrint(
        '[TechnicianProfileService] UID mismatch. auth=$authUid, requested=$uid. Using auth UID for Firestore writes.',
      );
    }

    print('📝 Saving onboarding profile for uid: $effectiveUid');

    final batch = _firestore.batch();
    final hasValidLocation = lat != null && lng != null;
    final normalizedSpecialties =
        TechnicianSpecialtyCatalog.normalizeList(data.specialties);
    final normalizedCustomSkills =
        TechnicianSpecialtyCatalog.normalizeList(data.customSkills);
    final servicesProvided = TechnicianSpecialtyCatalog.normalizeList([
      ...data.specialties,
      ...data.customSkills,
    ]);
    
    // 1. Update users collection (basic + public fields)
    final userRef = _firestore.collection('users').doc(effectiveUid);
    final userData = {
      'uid': effectiveUid,
      'email': email,
      'role': 'technician',
      'fullName': data.fullName ?? 'Technician',
      'profileImage': data.profilePhotoUrl,
      'bio': data.bio,
      'city': data.city,
      'speciality': servicesProvided.isNotEmpty ? servicesProvided.first : 'Specialist',
      'specialties': normalizedSpecialties,
      'servicesProvided': servicesProvided,
      'isAvailable': data.isAvailable,
      'availabilityEnabled': data.isAvailable,
      'isOnline': true,
      'onboardingCompleted': true,
      'profileCompleted': true,
      'activeAccount': true,
      'accountStatus': 'active',
      'isPhoneVerified': data.isPhoneVerified,
      'isIdentityVerified': data.identityDocumentUrl != null,
      'profileCompletionScore': 0.0,
      if (hasValidLocation) 'lat': lat,
      if (hasValidLocation) 'lng': lng,
      if (hasValidLocation) 'location': {
        'lat': lat,
        'lng': lng,
      },
      'updated_at': FieldValue.serverTimestamp(),
    };

    // 2. Create/update technician_profiles collection (extended data)
    final profileRef = _firestore.collection('technician_profiles').doc(effectiveUid);
    final profileCompletion = TechnicianProfileModel.calculateProfileCompletion(
      userData,
      {
        'specialties': normalizedSpecialties,
        'customSkills': normalizedCustomSkills,
        'yearsOfExperience': data.yearsOfExperience,
        'certificationUrls': data.certificationUrls,
        'portfolioUrls': data.portfolioUrls,
        'availableDays': data.availableDays,
        'isPhoneVerified': data.isPhoneVerified,
        'isIdentityVerified': data.identityDocumentUrl != null,
      },
    );
    final initialRankScore = TechnicianRankingService.calculateRankScore(
      averageRating: 0.0,
      totalReviews: 0,
      completedJobs: 0,
      responseSpeedScore: 0.0,
      profileCompletenessScore: profileCompletion,
      activityScore: 100.0,
      availabilityScore: data.isAvailable ? 100.0 : 0.0,
      availabilityEnabled: data.isAvailable,
    );
    userData['profileCompletionScore'] = profileCompletion;
    batch.set(userRef, userData, SetOptions(merge: true));
    
    final profileData = {
      'specialties': normalizedSpecialties,
      'customSkills': normalizedCustomSkills,
      'servicesProvided': servicesProvided,
      'primarySpecialty': servicesProvided.isNotEmpty ? servicesProvided.first : 'Specialist',
      'yearsOfExperience': data.yearsOfExperience,
      'certificationUrls': data.certificationUrls,
      'portfolioUrls': data.portfolioUrls,
      'isAvailable': data.isAvailable,
      'availabilityEnabled': data.isAvailable,
      'availableDays': data.availableDays,
      'workingHours': {
        'startHour': data.startHour,
        'startMinute': data.startMinute,
        'endHour': data.endHour,
        'endMinute': data.endMinute,
      },
      'serviceRadiusMiles': data.serviceRadiusMiles,
      if (hasValidLocation) 'lat': lat,
      if (hasValidLocation) 'lng': lng,
      if (hasValidLocation) 'location': {
        'lat': lat,
        'lng': lng,
      },
      if (data.age != null) 'age': data.age,
      if (data.city != null) 'city': data.city,
      if (data.bio != null) 'bio': data.bio,
      if (data.profilePhotoUrl != null) 'profilePhotoUrl': data.profilePhotoUrl,
      'isPhoneVerified': data.isPhoneVerified,
      'isIdentityVerified': data.identityDocumentUrl != null,
      'profileCompletionScore': profileCompletion,
      'profileCompleted': true,
      'activeAccount': true,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(profileRef, profileData, SetOptions(merge: true));

    // 2b. Save private technician onboarding data
    final privateProfileRef = _firestore.collection('technician_private_profiles').doc(effectiveUid);
    final privateData = {
      'uid': effectiveUid,
      if (data.phoneNumber != null) 'phoneNumber': data.phoneNumber,
      if (data.identityDocumentUrl != null) 'identityDocumentUrl': data.identityDocumentUrl,
      'isPhoneVerified': data.isPhoneVerified,
      'isIdentityVerified': data.identityDocumentUrl != null,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    batch.set(privateProfileRef, privateData, SetOptions(merge: true));
    
    // 3. Initialize technician_stats if not exists
    final statsRef = _firestore.collection('technician_stats').doc(effectiveUid);
    final statsData = {
      'technicianId': effectiveUid,
      'averageRating': 0.0,
      'totalReviews': 0,
      'completedJobs': 0,
      'reviewQualityScore': 100.0,
      'profileCompletionBonus': profileCompletion,
      'profileCompletenessScore': profileCompletion,
      'availabilityScore': data.isAvailable ? 100.0 : 0.0,
      'activityScore': 100.0,
      'responseSpeedScore': 0.0,
      'availabilityEnabled': data.isAvailable,
      'profileCompleted': true,
      'activeAccount': true,
      'accountStatus': 'active',
      'lastActivityAt': FieldValue.serverTimestamp(),
      'rankScore': initialRankScore,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    batch.set(statsRef, statsData, SetOptions(merge: true));
    
    await batch.commit();
    print('✅ Onboarding profile saved successfully');
    
    // Invalidate cache
    _profileCache.remove(effectiveUid);
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
    final normalizedSpecialties =
        specialties == null ? null : TechnicianSpecialtyCatalog.normalizeList(specialties);
    
    // Update users collection
    final userUpdates = <String, dynamic>{};
    if (fullName != null) userUpdates['fullName'] = fullName;
    if (bio != null) userUpdates['bio'] = bio;
    if (profilePhotoUrl != null) userUpdates['profileImage'] = profilePhotoUrl;
    if (city != null) userUpdates['city'] = city;
    if (isAvailable != null) {
      userUpdates['isAvailable'] = isAvailable;
      userUpdates['availabilityEnabled'] = isAvailable;
    }
    if (normalizedSpecialties != null && normalizedSpecialties.isNotEmpty) {
      userUpdates['speciality'] = normalizedSpecialties.first;
      userUpdates['servicesProvided'] = normalizedSpecialties;
    }
    userUpdates['updated_at'] = FieldValue.serverTimestamp();
    
    if (userUpdates.isNotEmpty) {
      batch.update(_firestore.collection('users').doc(uid), userUpdates);
    }
    
    // Update technician_profiles collection
    final profileUpdates = <String, dynamic>{};
    if (normalizedSpecialties != null) {
      profileUpdates['specialties'] = normalizedSpecialties;
      profileUpdates['servicesProvided'] = normalizedSpecialties;
      profileUpdates['primarySpecialty'] = normalizedSpecialties.isNotEmpty ? normalizedSpecialties.first : 'Technician';
    }
    if (workingHours != null) profileUpdates['workingHours'] = workingHours;
    if (isAvailable != null) {
      profileUpdates['isAvailable'] = isAvailable;
      profileUpdates['availabilityEnabled'] = isAvailable;
    }
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
      final responseSpeedScore = (statsData['responseSpeedScore'] as num?)?.toDouble() ?? 0.0;
      final activityScore = (statsData['activityScore'] as num?)?.toDouble() ?? 100.0;
      final availabilityScore = (statsData['availabilityScore'] as num?)?.toDouble() ?? 0.0;
      final availabilityEnabled = statsData['availabilityEnabled'] != false;

      final rankScore = TechnicianRankingService.calculateRankScore(
        averageRating: averageRating,
        totalReviews: totalReviews,
        completedJobs: completedJobs,
        responseSpeedScore: responseSpeedScore,
        profileCompletenessScore: completionScore,
        activityScore: activityScore,
        availabilityScore: availabilityScore,
        availabilityEnabled: availabilityEnabled,
      );
      
      // Update rankScore in technician_stats
      batch.set(
        _firestore.collection('technician_stats').doc(uid),
        {
          'profileCompletionBonus': completionScore,
          'profileCompletenessScore': completionScore,
          'rankScore': rankScore,
          'activityScore': 100.0,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      
      // Update users collection for backward compatibility
      batch.set(
        _firestore.collection('users').doc(uid),
        {
          'rankScore': rankScore,
          'profileCompletionScore': completionScore,
          'activityScore': 100.0,
          'lastActivityAt': FieldValue.serverTimestamp(),
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

      if (userData['profileCompleted'] == false ||
          userData['activeAccount'] == false ||
          userData['availabilityEnabled'] == false) {
        continue;
      }

      if (profile.location == null) {
        continue;
      }
      
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
    profiles.sort((a, b) {
      final scoreA = _effectiveRankScore(a.rankScore, a.updatedAt);
      final scoreB = _effectiveRankScore(b.rankScore, b.updatedAt);
      return scoreB.compareTo(scoreA);
    });
    
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
        // We do not filter by isAvailable strictly via Firestore because legacy accounts
        // might not have this field initialized to true, breaking backward compatibility.
        // without a composite index. We'll do it client-side since Spark plan
        // users often avoid maintaining multiple composite indexes.
        .snapshots()
        .map((snap) {
          var techs = snap.docs
              .where((doc) {
                final data = doc.data();
                return (data['onboardingCompleted'] == true ||
                        data['onboarding_done'] == true) &&
                    data['profileCompleted'] != false &&
                    data['activeAccount'] != false &&
                    data['availabilityEnabled'] != false &&
                    data['isAvailable'] != false &&
                    (data['lat'] is num || data['latitude'] is num || data['location'] is Map);
              })
              .map((doc) => MarketplaceTechnician.fromDoc(doc))
              .where((t) => t.isAvailable && t.location != null) // Client-side filtering ensures legacy compat
              .toList();
          
          for (final t in techs) {
            if (userLocation != null) {
              t.calculateDistance(userLocation);
            }
          }
          
          // Sort by a combination of rankScore and distance penalty
          techs.sort((a, b) {
            double scoreA = _effectiveRankScore(a.rankScore, a.updatedAt);
            double scoreB = _effectiveRankScore(b.rankScore, b.updatedAt);
            
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

  double _effectiveRankScore(double rankScore, DateTime updatedAt) {
    return rankScore + TechnicianRankingService.freshnessBonus(updatedAt);
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
