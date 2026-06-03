import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const QuickActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppColors.space12,
          vertical: AppColors.space12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          border: Border.all(
            color: backgroundColor != null ? backgroundColor!.withValues(alpha: 0.5) : AppColors.divider,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor ?? AppColors.neonAccent,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActions extends StatelessWidget {
  final VoidCallback onGoOnline;
  final VoidCallback onViewNearbyJobs;
  final VoidCallback onUpdateAvailability;
  final VoidCallback onOpenMessages;
  final VoidCallback onEmergencySupport;
  final bool isOnline;

  const QuickActions({
    super.key,
    required this.onGoOnline,
    required this.onViewNearbyJobs,
    required this.onUpdateAvailability,
    required this.onOpenMessages,
    required this.onEmergencySupport,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
          child: Text(
            'Quick Actions',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppColors.space12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
          child: SizedBox(
            height: 100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  QuickActionPill(
                    icon: isOnline ? Icons.pause_circle : Icons.play_circle,
                    label: isOnline ? 'Go Offline' : 'Go Online',
                    onTap: onGoOnline,
                    backgroundColor: isOnline ? AppColors.success.withValues(alpha: 0.15) : AppColors.neonAccent.withValues(alpha: 0.15),
                    iconColor: isOnline ? AppColors.success : AppColors.neonAccent,
                  ),
                  const SizedBox(width: AppColors.space12),
                  QuickActionPill(
                    icon: Icons.location_on,
                    label: 'Nearby Jobs',
                    onTap: onViewNearbyJobs,
                  ),
                  const SizedBox(width: AppColors.space12),
                  QuickActionPill(
                    icon: Icons.schedule,
                    label: 'Availability',
                    onTap: onUpdateAvailability,
                  ),
                  const SizedBox(width: AppColors.space12),
                  QuickActionPill(
                    icon: Icons.message,
                    label: 'Messages',
                    onTap: onOpenMessages,
                  ),
                  const SizedBox(width: AppColors.space12),
                  QuickActionPill(
                    icon: Icons.emergency,
                    label: 'Support',
                    onTap: onEmergencySupport,
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    iconColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
