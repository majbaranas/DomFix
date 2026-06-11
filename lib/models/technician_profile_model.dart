import 'package:cloud_firestore/cloud_firestore.dart';

/// Production-ready Technician Profile Model
/// 
/// Stores complete technician data in Firestore under:
/// - users/{uid} (basic info + role)
/// - technician_profiles/{uid} (extended professional data)
class TechnicianProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? profilePhotoUrl;
  final String? bio;
  final int? age;
  final String? city;
  
  // Professional Identity
  final List<String> specialties;
  final List<String> customSkills;
  final String primarySpecialty;
  
  // Experience & Portfolio
  final int yearsOfExperience;
  final List<String> certificationUrls;
  final List<String> portfolioUrls;
  
  // Availability
  final bool isAvailable;
  final List<String> availableDays;
  final TimeRange workingHours;
  final int serviceRadiusMiles;
  final GeoPoint? location;
  
  // Trust & Verification
  final bool isPhoneVerified;
  final bool isIdentityVerified;
  
  // Stats (read from technician_stats)
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final double rankScore;
  
  // Profile Completion
  final double profileCompletionScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String liveStatus;
  final DateTime? lastSeen;

  const TechnicianProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.profilePhotoUrl,
    this.bio,
    this.age,
    this.city,
    required this.specialties,
    required this.customSkills,
    required this.primarySpecialty,
    required this.yearsOfExperience,
    required this.certificationUrls,
    required this.portfolioUrls,
    required this.isAvailable,
    required this.availableDays,
    required this.workingHours,
    required this.serviceRadiusMiles,
    this.location,
    required this.isPhoneVerified,
    required this.isIdentityVerified,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.rankScore,
    required this.profileCompletionScore,
    required this.createdAt,
    required this.updatedAt,
    this.liveStatus = 'offline',
    this.lastSeen,
  });

  factory TechnicianProfileModel.fromFirestore(
    String id,
    Map<String, dynamic> userData,
    Map<String, dynamic>? profileData,
    Map<String, dynamic>? statsData,
  ) {
    final specialtiesList = (profileData?['specialties'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final customSkillsList = (profileData?['customSkills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    
    final primarySpec = profileData?['primarySpecialty'] as String? ??
        (specialtiesList.isNotEmpty ? specialtiesList.first : 'Technician');

    final certUrls = (profileData?['certificationUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final portfolioUrls = (profileData?['portfolioUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final availDays = (profileData?['availableDays'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return TechnicianProfileModel(
      id: id,
      fullName: userData['fullName'] ?? userData['name'] ?? 'Unknown',
      email: userData['email'] ?? '',
      profilePhotoUrl: userData['profileImage'] ?? profileData?['profilePhotoUrl'],
      bio: userData['bio'] ?? profileData?['bio'],
      age: profileData?['age'] as int?,
      city: userData['city'] ?? profileData?['city'],
      specialties: specialtiesList,
      customSkills: customSkillsList,
      primarySpecialty: primarySpec,
      yearsOfExperience: (profileData?['yearsOfExperience'] as num?)?.toInt() ?? 0,
      certificationUrls: certUrls,
      portfolioUrls: portfolioUrls,
      isAvailable: userData['isAvailable'] ?? profileData?['isAvailable'] ?? true,
      availableDays: availDays,
      workingHours: TimeRange.fromMap(profileData?['workingHours'] as Map<String, dynamic>?),
      serviceRadiusMiles: (profileData?['serviceRadiusMiles'] as num?)?.toInt() ?? 25,
      location: _parseGeoPoint(userData, profileData),
      isPhoneVerified: profileData?['isPhoneVerified'] ?? userData['isPhoneVerified'] ?? false,
      isIdentityVerified: profileData?['isIdentityVerified'] ?? userData['isIdentityVerified'] ?? false,
      rating: (statsData?['averageRating'] as num?)?.toDouble() ?? 
              (userData['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (statsData?['totalReviews'] as num?)?.toInt() ?? 
                   (userData['reviewCount'] as num?)?.toInt() ?? 0,
      completedJobs: (statsData?['completedJobs'] as num?)?.toInt() ?? 
                     (userData['jobsCompleted'] as num?)?.toInt() ?? 0,
      rankScore: (statsData?['rankScore'] as num?)?.toDouble() ?? 0.0,
      profileCompletionScore: calculateProfileCompletion(userData, profileData),
      createdAt: _parseTimestamp(userData['createdAt'] ?? userData['created_at']),
      updatedAt: _parseTimestamp(userData['updated_at'] ?? profileData?['updatedAt']),
      liveStatus: userData['liveStatus']?.toString() ?? 'offline',
      lastSeen: userData['lastSeen'] != null ? _parseTimestamp(userData['lastSeen']) : null,
    );
  }

  static GeoPoint? _parseGeoPoint(Map<String, dynamic> userData, Map<String, dynamic>? profileData) {
    final lat = userData['lat'] ?? profileData?['lat'];
    final lng = userData['lng'] ?? profileData?['lng'];
    if (lat != null && lng != null) {
      return GeoPoint((lat as num).toDouble(), (lng as num).toDouble());
    }
    return null;
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  static double calculateProfileCompletion(
    Map<String, dynamic> userData,
    Map<String, dynamic>? profileData,
  ) {
    int score = 0;
    int maxScore = 0;

    // Profile photo (15 points)
    maxScore += 15;
    if (userData['profileImage'] != null && (userData['profileImage'] as String).isNotEmpty) {
      score += 15;
    }

    // Bio (10 points)
    maxScore += 10;
    final bio = userData['bio'] ?? profileData?['bio'];
    if (bio != null && (bio as String).length > 50) {
      score += 10;
    }

    // Specialties (15 points)
    maxScore += 15;
    final specs = profileData?['specialties'] as List<dynamic>?;
    if (specs != null && specs.length >= 3) {
      score += 15;
    } else if (specs != null && specs.isNotEmpty) {
      score += 7;
    }

    // Experience (10 points)
    maxScore += 10;
    final exp = profileData?['yearsOfExperience'] as int?;
    if (exp != null && exp > 0) {
      score += 10;
    }

    // Portfolio (15 points)
    maxScore += 15;
    final portfolio = profileData?['portfolioUrls'] as List<dynamic>?;
    if (portfolio != null && portfolio.length >= 3) {
      score += 15;
    } else if (portfolio != null && portfolio.isNotEmpty) {
      score += 7;
    }

    // Certifications (10 points)
    maxScore += 10;
    final certs = profileData?['certificationUrls'] as List<dynamic>?;
    if (certs != null && certs.isNotEmpty) {
      score += 10;
    }

    // Identity verification (15 points)
    maxScore += 15;
    if (profileData?['isIdentityVerified'] == true || userData['isIdentityVerified'] == true) {
      score += 15;
    }

    // Phone verification (10 points)
    maxScore += 10;
    if (profileData?['isPhoneVerified'] == true || userData['isPhoneVerified'] == true) {
      score += 10;
    }

    return maxScore > 0 ? (score / maxScore * 100).clamp(0, 100) : 0;
  }

  Map<String, dynamic> toFirestoreProfile() {
    return {
      'specialties': specialties,
      'customSkills': customSkills,
      'primarySpecialty': primarySpecialty,
      'yearsOfExperience': yearsOfExperience,
      'certificationUrls': certificationUrls,
      'portfolioUrls': portfolioUrls,
      'isAvailable': isAvailable,
      'availableDays': availableDays,
      'workingHours': workingHours.toMap(),
      'serviceRadiusMiles': serviceRadiusMiles,
      if (age != null) 'age': age,
      if (city != null) 'city': city,
      if (bio != null) 'bio': bio,
      if (location != null) 'lat': location!.latitude,
      if (location != null) 'lng': location!.longitude,
      'isPhoneVerified': isPhoneVerified,
      'isIdentityVerified': isIdentityVerified,
      'profileCompletionScore': profileCompletionScore,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUser() {
    return {
      'fullName': fullName,
      'email': email,
      if (profilePhotoUrl != null) 'profileImage': profilePhotoUrl,
      if (bio != null) 'bio': bio,
      if (city != null) 'city': city,
      'isAvailable': isAvailable,
      if (location != null) 'lat': location!.latitude,
      if (location != null) 'lng': location!.longitude,
      'speciality': primarySpecialty,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  String get replyTime {
    if (completedJobs > 50) return '< 10m';
    if (completedJobs > 20) return '< 20m';
    if (completedJobs > 5) return '< 30m';
    return '< 1h';
  }

  String get profileTier {
    if (profileCompletionScore >= 90) return 'Gold';
    if (profileCompletionScore >= 70) return 'Silver';
    if (profileCompletionScore >= 50) return 'Bronze';
    return 'Basic';
  }
}

class TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  factory TimeRange.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TimeRange(startHour: 8, startMinute: 0, endHour: 18, endMinute: 0);
    }
    return TimeRange(
      startHour: map['startHour'] as int? ?? 8,
      startMinute: map['startMinute'] as int? ?? 0,
      endHour: map['endHour'] as int? ?? 18,
      endMinute: map['endMinute'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  String toDisplayString() {
    final start = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final end = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
