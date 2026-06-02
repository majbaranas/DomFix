import 'package:shared_preferences/shared_preferences.dart';

/// Local storage helper using SharedPreferences.
///
/// IMPORTANT: SharedPreferences is used ONLY as a session cache.
/// Firebase Firestore is the source of truth. Always sync from Firestore
/// on app start or after login.
class PreferencesService {
  // ─── Keys (spec-aligned) ──────────────────────────────────────────────────
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserRole = 'user_role';
  static const String _keyOnboardingDone = 'onboarding_done';
  static const String _keyFirstLaunch = 'isFirstLaunch'; // app intro screens

  // ─── is_logged_in ─────────────────────────────────────────────────────────

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
  }

  // ─── user_role ────────────────────────────────────────────────────────────

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  static Future<void> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  static Future<bool> hasRole() async {
    final role = await getUserRole();
    return role != null && role.isNotEmpty;
  }

  // ─── onboarding_done ──────────────────────────────────────────────────────

  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingDone) ?? false;
  }

  static Future<void> setOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, value);
  }

  // ─── App intro (first launch) ─────────────────────────────────────────────

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  // ─── Sync helpers ─────────────────────────────────────────────────────────

  /// Sync Firestore user data into local cache after login or app start.
  static Future<void> syncFromFirestore({
    required String role,
    required bool onboardingDone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserRole, role);
    await prefs.setBool(_keyOnboardingDone, onboardingDone);
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  /// Clears all auth-related keys. Call on logout.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyOnboardingDone);
  }

  // ─── Legacy aliases (backward-compat during migration) ────────────────────

  /// @deprecated Use [isOnboardingDone]
  static Future<bool> isOnboardingCompleted() => isOnboardingDone();

  /// @deprecated Use [setOnboardingDone]
  static Future<void> setOnboardingCompleted(bool value) =>
      setOnboardingDone(value);
}
