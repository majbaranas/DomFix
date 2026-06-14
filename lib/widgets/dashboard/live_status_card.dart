import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/dashboard_metrics.dart';

class LiveStatusCard extends StatefulWidget {
  final DashboardMetrics metrics;
  final Function(bool) onStatusToggle;

  const LiveStatusCard({
    super.key,
    required this.metrics,
    required this.onStatusToggle,
  });

  @override
  State<LiveStatusCard> createState() => _LiveStatusCardState();
}

class _LiveStatusCardState extends State<LiveStatusCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
      child: GestureDetector(
        onTap: () => widget.onStatusToggle(!widget.metrics.isOnline),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.metrics.isOnline ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.neonAccent.withValues(alpha: 0.15),
                  AppColors.neonAccent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: AppColors.neonAccent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonAccent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.metrics.isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                                boxShadow: widget.metrics.isOnline
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              widget.metrics.isOnline ? 'Online' : 'Offline',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: widget.metrics.isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onStatusToggle(!widget.metrics.isOnline),
                      child: Container(
                        width: 60,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.metrics.isOnline
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.metrics.isOnline ? AppColors.success : AppColors.divider,
                          ),
                        ),
                        child: Center(
                          child: AnimatedAlign(
                            alignment: widget.metrics.isOnline ? Alignment.centerRight : Alignment.centerLeft,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.metrics.isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricColumn(
                      label: "Today's Earnings",
                      value: '\$${widget.metrics.todayEarnings.toStringAsFixed(0)}',
                      icon: '💰',
                    ),
                    _MetricColumn(
                      label: 'Active Jobs',
                      value: '${widget.metrics.activeJobsCount}',
                      icon: '📋',
                    ),
                    _MetricColumn(
                      label: 'Completion',
                      value: '${widget.metrics.completionRate.toStringAsFixed(0)}%',
                      icon: '✓',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricColumn(
                      label: 'Response Time',
                      value: '${widget.metrics.responseTimeMinutes}m',
                      icon: '⚡',
                    ),
                    _MetricColumn(
                      label: 'Rating',
                      value: widget.metrics.customerRating.toStringAsFixed(1),
                      icon: '⭐',
                    ),
                    _MetricColumn(
                      label: 'Weekly Earnings',
                      value: '\$${widget.metrics.weeklyEarnings.toStringAsFixed(0)}',
                      icon: '📊',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 18),
          ),
          SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Text(
                value.contains('.') || value.contains('%')
                    ? value
                    : value.contains('\$')
                        ? '\$${val.toInt()}'
                        : value.contains('m')
                            ? '${val.toInt()}m'
                            : val.toStringAsFixed(1),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonAccent,
                ),
              );
            },
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
