import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_navigation_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  final _authService = AuthService();
  @override
  bool get wantKeepAlive => true;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Logout', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
      await LocalStorageService.clearAll();
      if (mounted) await NavigationService.logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const SizedBox(height: 24),
              _settingItem(Icons.person_outline_rounded, 'Profile', () {}),
              _settingItem(Icons.notifications_outlined, 'Notifications', () {}),
              _settingItem(Icons.shield_outlined, 'Privacy & Security', () {}),
              _settingItem(Icons.help_outline_rounded, 'Help & Support', () {}),
              const SizedBox(height: 16),
              _logoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Row(children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onSurface))),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
        ]),
      ),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Text('Logout', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error)),
        ]),
      ),
    );
  }
}
