import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/dashboard_metrics.dart';
import 'premium_animations.dart';

class PremiumStatusHero extends StatefulWidget {
  final DashboardMetrics metrics;
  final Function(bool) onStatusToggle;

  const PremiumStatusHero({
    super.key,
    required this.metrics,
    required this.onStatusToggle,
  });

  @override
  State<PremiumStatusHero> createState() => _PremiumStatusHeroState();
}

class _PremiumStatusHeroState extends State<PremiumStatusHero> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: PremiumAnimations.subtle,
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
      child: GestureDetector(
        onTap: () => widget.onStatusToggle(!widget.metrics.isOnline),
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
            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
            border: Border.all(
              color: AppColors.neonAccent.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonAccent.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppColors.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status + Toggle
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
                      const SizedBox(height: 8),
                      // Animated status indicator
                      PremiumAnimations.buildPulseAnimation(
                        controller: _pulseController,
                        child: Row(
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
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.metrics.isOnline ? 'Online & Active' : 'Offline',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: widget.metrics.isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Premium toggle switch
                  GestureDetector(
                    onTap: () => widget.onStatusToggle(!widget.metrics.isOnline),
                    child: Container(
                      width: 64,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.metrics.isOnline
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: widget.metrics.isOnline ? AppColors.success : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: AnimatedAlign(
                          alignment: widget.metrics.isOnline ? Alignment.centerRight : Alignment.centerLeft,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            width: 26,
                            height: 26,
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
              const SizedBox(height: 28),

              // Key metrics grid (2x3)
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppColors.space12,
                  mainAxisSpacing: AppColors.space16,
                  childAspectRatio: 1.0,
                ),
                children: [
                  _MetricTile(
                    label: "Today's Earnings",
                    value: '\$${widget.metrics.todayEarnings.toStringAsFixed(0)}',
                    icon: '💰',
                    color: AppColors.neonAccent,
                  ),
                  _MetricTile(
                    label: 'Active Jobs',
                    value: '${widget.metrics.activeJobsCount}',
                    icon: '📋',
                    color: Colors.cyan,
                  ),
                  _MetricTile(
                    label: 'Completion',
                    value: '${widget.metrics.completionRate.toStringAsFixed(0)}%',
                    icon: '✓',
                    color: AppColors.success,
                  ),
                  _MetricTile(
                    label: 'Response Time',
                    value: '${widget.metrics.responseTimeMinutes}m',
                    icon: '⚡',
                    color: Colors.amber,
                  ),
                  _MetricTile(
                    label: 'Rating',
                    value: widget.metrics.customerRating.toStringAsFixed(1),
                    icon: '⭐',
                    color: Colors.amber,
                  ),
                  _MetricTile(
                    label: 'Weekly Earnings',
                    value: '\$${widget.metrics.weeklyEarnings.toStringAsFixed(0)}',
                    icon: '📊',
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(AppColors.space12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0),
            duration: const Duration(milliseconds: 1200),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
