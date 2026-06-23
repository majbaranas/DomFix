import 'package:flutter/material.dart';
import 'premium_technician_profile_screen.dart';

/// Production-ready Technician Profile Screen (Client-facing).
/// Now delegates entirely to PremiumTechnicianProfileScreen
/// in Client Mode (read-only, with Book Now / Message actions).
class TechnicianProfileScreen extends StatelessWidget {
  final String technicianId;
  final String? initialName;

  const TechnicianProfileScreen({
    super.key,
    required this.technicianId,
    this.initialName,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumTechnicianProfileScreen(
      technicianId: technicianId,
      isTechnicianMode: false,
    );
  }
}
