import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  final String technicianId;
  final String performanceBadge;
  final bool isOnline;

  const DashboardHeader({
    super.key,
    required this.technicianId,
    required this.performanceBadge,
    required this.isOnline,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(technicianId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 100,
            child: Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surface.withValues(alpha: 0.2),
              child: Container(height: 100, color: AppColors.surface),
            ),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['fullName'] ?? userData?['name'] ?? 'Technician';
        final profileImage = userData?['profileImage'];

        return Padding(
          padding: const EdgeInsets.all(AppColors.space20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.neonAccent, width: 2),
                          color: AppColors.surface,
                        ),
                        child: ClipOval(
                          child: profileImage != null
                              ? Image.network(profileImage, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.neonAccent,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: isOnline
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.success,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppColors.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.neonAccent,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppColors.space16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.space12,
                  vertical: AppColors.space8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.neonAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      performanceBadge,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neonAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const Shimmer.fromColors({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
