import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox(double width, double height) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
              colors: [
                AppColors.surfaceContainerLow.withValues(alpha: 0.92),
                AppColors.surfaceContainerHigh.withValues(alpha: 0.98),
                AppColors.surfaceContainerLow.withValues(alpha: 0.92),
              ],
            ).createShader(bounds);
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.whiteBorder5,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.85),
          radius: 1.2,
          colors: [
            AppColors.neonAccent.withValues(alpha: 0.06),
            AppColors.background,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShimmerBox(56, 56),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(120, 14),
                      SizedBox(height: 8),
                      _buildShimmerBox(180, 24),
                    ],
                  ),
                ),
                _buildShimmerBox(40, 40),
            ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonAccent.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonAccent.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading technician dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildShimmerBox(double.infinity, 200),
            const SizedBox(height: 18),
            _buildShimmerBox(150, 18),
            const SizedBox(height: 12),
            _buildShimmerBox(double.infinity, 170),
            const SizedBox(height: 18),
            _buildShimmerBox(130, 18),
            const SizedBox(height: 12),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              children: List.generate(
                4,
                (_) => _buildShimmerBox(double.infinity, 120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
