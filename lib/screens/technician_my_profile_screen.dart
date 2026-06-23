import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'premium_technician_profile_screen.dart';

/// Technician's own profile view — used inside the tab bar.
/// Now delegates entirely to the unified PremiumTechnicianProfileScreen
/// in Technician Mode (editable).
class TechnicianMyProfileScreen extends StatelessWidget {
  const TechnicianMyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }
    return PremiumTechnicianProfileScreen(
      technicianId: uid,
      isTechnicianMode: true,
    );
  }
}
