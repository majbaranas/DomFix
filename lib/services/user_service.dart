import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore `users/{uid}` — role and onboarding always read from here.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';

  static const String fieldUid = 'uid';
  static const String fieldEmail = 'email';
  static const String fieldRole = 'role';
  static const String fieldOnboardingCompleted = 'onboardingCompleted';
  static const String fieldOnboardingDoneLegacy = 'onboarding_done';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldCreatedAtLegacy = 'created_at';
  static const String fieldName = 'name';
  static const String fieldProfileImage = 'profileImage';

  /// Prefer [onboardingCompleted]; fall back to legacy [onboarding_done].
  static bool parseOnboardingCompleted(Map<String, dynamic>? data) {
    if (data == null) return false;
    final v = data[fieldOnboardingCompleted] ?? data[fieldOnboardingDoneLegacy];
    if (v is bool) return v;
    return false;
  }

  /// `null` if missing, empty, or whitespace.
  static String? parseRole(Map<String, dynamic>? data) {
    if (data == null) return null;
    final r = data[fieldRole];
    if (r is! String) return null;
    final s = r.trim();
    if (s.isEmpty) return null;
    return s;
  }

  /// Create or merge base profile after sign-up (no [role] until role selection).
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
    String? name,
  }) async {
    try {
      final ref = _firestore.collection(usersCollection).doc(uid);
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          fieldUid: uid,
          fieldEmail: email,
          if (name != null && name.trim().isNotEmpty) fieldName: name.trim(),
          fieldOnboardingCompleted: false,
          fieldCreatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await ref.set({
        fieldUid: uid,
        fieldEmail: email,
        if (name != null && name.trim().isNotEmpty) fieldName: name.trim(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error ensuring user document: $e');
      rethrow;
    }
  }

  /// Optional profile fields (e.g. Cloudinary URL).
  Future<void> updateProfileFields(
    String uid, {
    String? name,
    String? profileImageUrl,
  }) async {
    try {
      final map = <String, dynamic>{};
      if (name != null) map[fieldName] = name;
      if (profileImageUrl != null) map[fieldProfileImage] = profileImageUrl;
      if (map.isEmpty) return;
      await _firestore
          .collection(usersCollection)
          .doc(uid)
          .set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating profile fields: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      rethrow;
    }
  }

  /// Get user by ID (alias for getUserData for clarity)
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    return getUserData(uid);
  }

  Future<void> updateUserRole(String uid, String role) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).set({
        fieldRole: role,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  Future<void> updateOnboardingStatus(String uid, bool completed) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).set({
        fieldOnboardingCompleted: completed,
        fieldOnboardingDoneLegacy: completed,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating onboarding status: $e');
      rethrow;
    }
  }

  Future<bool> userExists(String uid) async {
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }

  Future<String?> getUserRole(String uid) async {
    final userData = await getUserData(uid);
    return parseRole(userData);
  }

  Future<bool> getOnboardingStatus(String uid) async {
    final userData = await getUserData(uid);
    return parseOnboardingCompleted(userData);
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }
}
