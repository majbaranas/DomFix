import 'package:flutter/material.dart';

import 'main_layout.dart';

/// Client root: single shell with global bottom navigation.
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainLayout();
  }
}
