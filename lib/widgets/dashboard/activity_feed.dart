import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/dashboard_metrics.dart';

class ActivityItemWidget extends StatelessWidget {
  final ActivityItem activity;
  final int index;
  final int totalCount;

  const ActivityItemWidget({
    super.key,
    required this.activity,
    required this.index,
    required this.totalCount,
  });

  IconData _getActivityIcon() {
    switch (activity.type) {
      case 'booking':
        return Icons.check_circle;
      case 'payment':
        return Icons.payment;
      case 'review':
        return Icons.star;
      case 'message':
        return Icons.chat;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor() {
    switch (activity.type) {
      case 'booking':
        return AppColors.neonAccent;
      case 'payment':
        return AppColors.success;
      case 'review':
        return Colors.amber;
      case 'message':
        return Colors.blue;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getActivityColor().withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getActivityIcon(),
                color: _getActivityColor(),
                size: 18,
              ),
            ),
            if (index < totalCount - 1)
              Container(
                width: 2,
                height: 24,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        SizedBox(width: AppSpacing.space16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: 4,
              bottom: index == totalCount - 1 ? 0 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  activity.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activity.timeAgo,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    if (activity.metadata != null)
                      Text(
                        activity.metadata!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getActivityColor(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ActivityFeed extends StatelessWidget {
  final List<ActivityItem> activities;

  const ActivityFeed({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: Text(
            'Recent Activity',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.space12),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.space20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Column(
                children: List.generate(
                  activities.length,
                  (index) => ActivityItemWidget(
                    activity: activities[index],
                    index: index,
                    totalCount: activities.length,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
