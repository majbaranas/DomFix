import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Premium AI Hero Card — cinematic futuristic centerpiece.
/// Matches HTML design: gradient bg, decorative blur, floating sparkles, particles, badge, CTA.
class HeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const HeroCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.3, -1.0),
            end: Alignment(0.3, 1.0),
            colors: [
              Color(0xFF1C2025),
              Color(0xFF101419),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative blur circle top-right
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Decorative sparkles + particles on the right
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient glow behind sparkles
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.neonAccent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Floating sparkles icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 2 * pi),
                        duration: const Duration(seconds: 6),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, sin(value) * 10),
                            child: child,
                          );
                        },
                        child: Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: AppColors.neonAccent.withValues(alpha: 0.40),
                        ),
                      ),
                      // Top-left particle (ping effect)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _PulseDot(size: 8, color: AppColors.neonAccent.withValues(alpha: 0.40)),
                      ),
                      // Bottom-right particle (pulse effect)
                      Positioned(
                        bottom: 16,
                        right: 8,
                        child: _PulseDot(size: 6, color: AppColors.neonAccent.withValues(alpha: 0.30)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI DIAGNOSTICS badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: AppColors.neonAccent),
                        const SizedBox(width: 6),
                        Text(
                          'AI DIAGNOSTICS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neonAccent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Describe your issue',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI will diagnose your home repair problem instantly.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonAccent.withValues(alpha: 0.20),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start Diagnosis',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimaryFixed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: AppColors.onPrimaryFixed,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  const _PulseDot({required this.size, required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scale = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
