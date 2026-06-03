import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/dashboard_metrics.dart';

class AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final List<double>? chartData;
  final Color accentColor;
  final IconData icon;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.chartData,
    this.accentColor = AppColors.neonAccent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(AppColors.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Text(
                    val.toStringAsFixed(value.contains('.') ? 1 : 0),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (chartData != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: _MiniChart(data: chartData!, color: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _MiniChart({
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final normalizedData = maxValue > 0 ? data.map((v) => v / maxValue).toList() : List.filled(data.length, 0.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          normalizedData.length,
          (index) {
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3 + (normalizedData[index] * 0.7)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (normalizedData[index] > 0.7)
                            Container(
                              width: double.infinity,
                              height: 2,
                              color: color,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnalyticsSection extends StatelessWidget {
  final DashboardMetrics metrics;

  const AnalyticsSection({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
          child: Text(
            'Performance Analytics',
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
          child: GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppColors.space12,
              mainAxisSpacing: AppColors.space12,
              childAspectRatio: 1.1,
            ),
            children: [
              AnalyticsCard(
                title: 'Weekly Earnings',
                value: metrics.weeklyEarnings.toStringAsFixed(0),
                unit: '\$',
                icon: Icons.trending_up,
                accentColor: AppColors.neonAccent,
                chartData: metrics.weeklyEarningsData,
              ),
              AnalyticsCard(
                title: 'Completed Jobs',
                value: metrics.completedJobsCount.toString(),
                unit: 'jobs',
                icon: Icons.check_circle,
                accentColor: AppColors.success,
              ),
              AnalyticsCard(
                title: 'Satisfaction',
                value: metrics.customerRating.toStringAsFixed(1),
                unit: '/5',
                icon: Icons.star,
                accentColor: Colors.amber,
              ),
              AnalyticsCard(
                title: 'Completion Rate',
                value: metrics.completionRate.toStringAsFixed(0),
                unit: '%',
                icon: Icons.pie_chart,
                accentColor: Colors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
