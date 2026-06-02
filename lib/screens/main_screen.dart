import 'package:flutter/material.dart';

import 'main_layout.dart';

/// Legacy entry name; delegates to [MainLayout].
class MainScreen extends StatelessWidget {
  const MainScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  Widget build(BuildContext context) {
    return MainLayout(initialTabIndex: initialPage);
  }
}
