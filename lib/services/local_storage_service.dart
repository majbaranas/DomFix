import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence: app-first-launch and optional "logged in" hint only.
/// Role and onboarding state MUST come from Firestore, not from here.
class LocalStorageService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyFirstLaunch = 'isFirstLaunch';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
  }

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
  }

  // ─── Language Local Persistence ────────────────────────
  static const String _keyLanguageCode = 'language_code';

  static Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguageCode) ?? 'en';
  }

  static Future<void> setLanguageCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguageCode, value);
  }
}
