import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/login_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/client_home_screen.dart';
import '../screens/technician_home_screen.dart';
import '../screens/onboarding/technician_onboarding_flow.dart';
import '../theme/app_colors.dart';
import '../models/technician_onboarding_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'user_service.dart';
import 'local_storage_service.dart';
import 'technician_profile_service.dart';

class NavigationService {
  static final UserService _userService = UserService();

  /// Single entry: Firebase session + Firestore `users/{uid}`.
  static Future<void> navigateBasedOnAuth(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (!context.mounted) return;

    if (user == null) {
      await LocalStorageService.clearAll();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      final userData = await _userService.getUserData(user.uid);

      if (!context.mounted) return;

      if (userData == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
        return;
      }

      final role = UserService.parseRole(userData);
      final onboardingDone = UserService.parseOnboardingCompleted(userData);

      await LocalStorageService.setLoggedIn(true);

      if (!context.mounted) return;

      if (role == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
        return;
      }

      if (role == 'client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
        );
        return;
      }

      if (role == 'technician') {
        if (!onboardingDone) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (routeContext) => Scaffold(
                backgroundColor: AppColors.background,
                body: TechnicianOnboardingFlow(
                  onComplete: (data) async {
                    await _onTechnicianOnboardingComplete(
                      routeContext,
                      user.uid,
                      data,
                    );
                  },
                ),
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TechnicianHomeScreen()),
          );
        }
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    } catch (e, st) {
      debugPrint('navigateBasedOnAuth error: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your profile. Check connection and try again.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  static Future<void> completeTechnicianOnboarding({
    required String uid,
    required String email,
    required TechnicianOnboardingData data,
    required double lat,
    required double lng,
  }) async {
    // Use TechnicianProfileService to save complete profile
    final profileService = TechnicianProfileService();
    await profileService.saveOnboardingProfile(
      uid: uid,
      email: email,
      data: data,
      lat: lat,
      lng: lng,
    );
  }

  static Future<void> _onTechnicianOnboardingComplete(
    BuildContext routeContext,
    String uid,
    TechnicianOnboardingData data,
  ) async {
    print('[NavigationService] 🚀 Starting technician onboarding completion...');
    
    try {
      // 1. Get user email
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final email = user.email ?? '';
      
      // 2. Fetch location
      double lat = 0.0;
      double lng = 0.0;
      
      print('[NavigationService] 📍 Fetching location...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          lat = position.latitude;
          lng = position.longitude;
          print('[NavigationService] ✅ Location: $lat, $lng');
        } else {
          print('[NavigationService] ⚠️ Location permission denied, using default');
        }
      } else {
        print('[NavigationService] ⚠️ Location services disabled');
      }

      print('[NavigationService] 💾 Saving complete profile to Firestore...');
      print('[NavigationService]   Full Name: ${data.fullName}');
      print('[NavigationService]   Specialties: ${data.specialties.length}');
      print('[NavigationService]   Portfolio: ${data.portfolioImages.length} images');
      print('[NavigationService]   Certifications: ${data.certifications.length}');
      print('[NavigationService]   Experience: ${data.yearsOfExperience} years');
      
      // 3. Save complete onboarding profile using TechnicianProfileService
      await completeTechnicianOnboarding(
        uid: uid,
        email: email,
        data: data,
        lat: lat,
        lng: lng,
      );

      print('[NavigationService] ✅ Profile saved successfully!');
      print('[NavigationService] 🎉 Onboarding complete! Navigating to dashboard...');
    } catch (e, st) {
      print('[NavigationService] ❌ ERROR: $e');
      debugPrint('Onboarding Firestore update failed: $e\n$st');
      if (routeContext.mounted) {
        ScaffoldMessenger.of(routeContext).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      return;
    }

    if (!routeContext.mounted) return;

    Navigator.of(routeContext, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TechnicianHomeScreen()),
      (route) => false,
    );
  }

  static Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearAll();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
