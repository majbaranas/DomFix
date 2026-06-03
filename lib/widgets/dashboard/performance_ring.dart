import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../theme/app_colors.dart';

class PerformanceRing extends StatefulWidget {
  final double completionRate;
  final double customerRating;
  final String performanceBadge;

  const PerformanceRing({
    super.key,
    required this.completionRate,
    required this.customerRating,
    required this.performanceBadge,
  });

  @override
  State<PerformanceRing> createState() => _PerformanceRingState();
}

class _PerformanceRingState extends State<PerformanceRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface.withValues(alpha: 0.6),
              AppColors.surfaceContainer.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(AppColors.space20),
        child: Column(
          children: [
            Text(
              'Performance Score',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            // Circular progress indicator
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ring
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _ProgressRingPainter(
                        progress: 1.0,
                        strokeWidth: 8,
                        color: AppColors.divider,
                        glowColor: Colors.transparent,
                      ),
                    ),
                    // Animated progress ring
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(140, 140),
                          painter: _ProgressRingPainter(
                            progress: (_controller.value * (widget.completionRate / 100)).clamp(0.0, 1.0),
                            strokeWidth: 8,
                            color: AppColors.neonAccent,
                            glowColor: AppColors.neonAccent.withValues(alpha: 0.4),
                          ),
                        );
                      },
                    ),
                    // Center content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: widget.completionRate),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) {
                            return Text(
                              '${val.toStringAsFixed(0)}%',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neonAccent,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completed',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatColumn(
                  label: 'Rating',
                  value: widget.customerRating.toStringAsFixed(1),
                  suffix: '/5',
                  icon: '⭐',
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                _StatColumn(
                  label: 'Status',
                  value: widget.performanceBadge,
                  icon: '🏆',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final String suffix;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonAccent,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color glowColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Glow effect
    if (glowColor.alpha > 0) {
      final glowPaint = Paint()
        ..color = glowColor
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        glowPaint,
      );
    }

    // Main ring
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
