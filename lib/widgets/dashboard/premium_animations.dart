import 'package:flutter/material.dart';

/// Shared animation utilities for premium dashboard widgets
class PremiumAnimations {
  static const Duration subtle = Duration(milliseconds: 400);
  static const Duration medium = Duration(milliseconds: 600);
  static const Duration slow = Duration(milliseconds: 1200);

  /// Pulse animation for live status indicators
  static Widget buildPulseAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        );
        return Transform.scale(scale: pulse.value, child: child);
      },
    );
  }

  /// Fade-in animation for staggered entry
  static Widget buildFadeIn({
    required Widget child,
    required AnimationController controller,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final startTime = delay.inMilliseconds.toDouble();
        final totalDuration = subtle.inMilliseconds.toDouble();
        final progress = ((controller.value * totalDuration) - startTime).clamp(0.0, totalDuration) / totalDuration;

        return Opacity(opacity: progress, child: child);
      },
    );
  }

  /// Scale + fade animation for card appearance
  static Widget buildScaleIn({
    required Widget child,
    required AnimationController controller,
    double from = 0.85,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = Tween<double>(begin: from, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        );

        return Transform.scale(
          scale: scale.value,
          child: Opacity(opacity: opacity.value, child: child),
        );
      },
    );
  }

  /// Slide up animation
  static Widget buildSlideUp({
    required Widget child,
    required AnimationController controller,
    double from = 20.0,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = Tween<Offset>(
          begin: Offset(0, from),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        );

        return Transform.translate(
          offset: offset.value,
          child: Opacity(opacity: opacity.value, child: child),
        );
      },
    );
  }

  /// Staggered animation sequence for multiple children
  static Future<void> staggerAnimations({
    required AnimationController controller,
    required int itemCount,
    Duration interval = const Duration(milliseconds: 50),
  }) async {
    controller.forward();
    for (int i = 0; i < itemCount; i++) {
      await Future.delayed(interval);
    }
  }

  /// Floating animation (subtle up-down motion)
  static Widget buildFloating({
    required Widget child,
    required AnimationController controller,
    double distance = 4.0,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = sin(controller.value * 2 * 3.14159) * distance;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
    );
  }

  /// Shimmer loading animation
  static Widget buildShimmer({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - controller.value * 2, 0),
              end: Alignment(1.0 + controller.value * 2, 0),
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

import 'dart:math';
