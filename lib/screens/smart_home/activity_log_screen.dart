import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/activity_log.dart';
import '../../services/activity_log_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          'Activity Timeline',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => ActivityLogService.instance.clearLogs(),
          ),
        ],
      ),
      body: StreamBuilder<List<ActivityLog>>(
        stream: ActivityLogService.instance.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.neonAccent),
            );
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Text(
                'No activity yet',
                style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _LogItem(log: log);
            },
          );
        },
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  const _LogItem({required this.log});
  final ActivityLog log;

  IconData _getIcon() {
    switch (log.type) {
      case LogType.deviceToggled:
        return Icons.power_settings_new_rounded;
      case LogType.sensorThreshold:
        return Icons.sensors_rounded;
      case LogType.automationTriggered:
        return Icons.auto_awesome_rounded;
      case LogType.aiRecommendation:
        return Icons.smart_toy_rounded;
      case LogType.error:
        return Icons.error_outline_rounded;
    }
  }

  Color _getColor() {
    switch (log.type) {
      case LogType.deviceToggled:
        return AppColors.neonAccent;
      case LogType.sensorThreshold:
        return Colors.orangeAccent;
      case LogType.automationTriggered:
        return Colors.purpleAccent;
      case LogType.aiRecommendation:
        return Colors.blueAccent;
      case LogType.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIcon(), color: _getColor(), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  log.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat.Hm().format(log.timestamp),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
