import 'package:flutter/material.dart';

import 'find_pros_screen_content.dart';

/// Technician discovery flow (often referred to as "find_technicien" in designs).
/// Same UI as the Pros tab body: list + header with map entry to [NearbyTechniciansMapScreen].
class FindTechnicianScreen extends StatelessWidget {
  const FindTechnicianScreen({super.key});

  @override
  Widget build(BuildContext context) => const FindProsScreenContent();
}
