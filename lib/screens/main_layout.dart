import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/domfix_glass_bottom_nav.dart';
import 'find_pros_screen_content.dart';
import 'home_screen_content.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';
import 'smart_home_screen.dart';

/// Exposes tab switching to descendants (e.g. home shortcuts) without pushing routes.
class MainLayoutScope extends InheritedWidget {
  const MainLayoutScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final ValueChanged<int> selectTab;

  static MainLayoutScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<MainLayoutScope>();
  }

  @override
  bool updateShouldNotify(MainLayoutScope oldWidget) => false;
}

/// Single app shell: persistent bottom nav + tab bodies with preserved state.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;

  static const List<Widget> _tabBodies = [
    HomeScreenContent(),
    MessagesScreen(),
    FindProsScreenContent(),
    SmartHomeScreen(), // ESP32 + IoT Control
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, _tabBodies.length - 1);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutScope(
      selectTab: _onTabSelected,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          sizing: StackFit.expand,
          children: _tabBodies,
        ),
        bottomNavigationBar: DomfixGlassBottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}
