import 'package:flutter/material.dart';

/// DomFix Design System — Premium Dark UI
///
/// Pixel-accurate color mapping from the HTML/Tailwind reference design.
/// High contrast, intentional accent usage, consistent spacing, zero visual noise.
class AppColors {
  AppColors._();

  // ─── Core Surfaces (from HTML design) ─────────────────
  static const Color background              = Color(0xFF070B14);  // html: #070B14
  static const Color surface                 = Color(0xFF101419);  // html: surface / #101419
  static const Color surfaceDim              = Color(0xFF101419);
  static const Color surfaceBright           = Color(0xFF36393F);

  static const Color surfaceContainerLowest  = Color(0xFF0A0E13);  // html: surface-container-lowest
  static const Color surfaceContainerLow     = Color(0xFF121826);  // spec: secondary surface
  static const Color surfaceContainer        = Color(0xFF1C2025);  // html: surface-container
  static const Color surfaceContainerHigh    = Color(0xFF1A2233);  // spec: surface elevated
  static const Color surfaceContainerHighest = Color(0xFF31353B);  // html: surface-container-highest
  static const Color surfaceVariant          = Color(0xFF31353B);

  // ─── On Surface (Text) ─────────────────────────────────
  static const Color onSurface              = Color(0xFFE0E2EA);  // html: on-surface / on-background
  static const Color onSurfaceVariant       = Color(0xFFC5C9AC);  // html: on-surface-variant
  static const Color onBackground           = Color(0xFFE0E2EA);

  // ─── Primary / Neon Accent ─────────────────────────────
  static const Color primaryContainer       = Color(0xFFCDF200);  // html: primary-container
  static const Color neonAccent             = Color(0xFFD9FF00);  // html: #D9FF00 accent
  static const Color primaryFixed           = Color(0xFFCDF200);  // html: primary-fixed
  static const Color primaryFixedDim        = Color(0xFFB4D400);  // html: primary-fixed-dim
  static const Color onPrimary              = Color(0xFF2B3400);  // html: on-primary
  static const Color onPrimaryFixed         = Color(0xFF181E00);  // html: on-primary-fixed
  static const Color onPrimaryContainer     = Color(0xFF5A6B00);  // html: on-primary-container
  static const Color inversePrimary         = Color(0xFF556500);  // html: inverse-primary
  static const Color surfaceTint            = Color(0xFFB4D400);  // html: surface-tint

  // ─── Secondary ─────────────────────────────────────────
  static const Color secondary              = Color(0xFFC2C6D6);  // html: secondary
  static const Color secondaryContainer     = Color(0xFF444956);  // html: secondary-container
  static const Color onSecondary            = Color(0xFF2B303D);  // html: on-secondary
  static const Color secondaryFixed         = Color(0xFFDEE2F3);  // html: secondary-fixed
  static const Color secondaryFixedDim      = Color(0xFFC2C6D6);
  static const Color onSecondaryContainer   = Color(0xFFB4B8C8);  // html: on-secondary-container
  static const Color onSecondaryFixed       = Color(0xFF161B27);
  static const Color onSecondaryFixedVariant = Color(0xFF424754);

  // ─── Tertiary ──────────────────────────────────────────
  static const Color tertiaryContainer      = Color(0xFFCEE6F2);  // html: tertiary-container
  static const Color onTertiary             = Color(0xFF1C333D);
  static const Color onTertiaryContainer    = Color(0xFF516872);

  // ─── Error ─────────────────────────────────────────────
  static const Color error                  = Color(0xFFFFB4AB);  // html: error
  static const Color errorContainer         = Color(0xFF93000A);  // html: error-container
  static const Color onError                = Color(0xFF690005);
  static const Color onErrorContainer       = Color(0xFFFFDAD6);
  static const Color emergency              = Color(0xFFFF4D4D);  // html: emergency accent

  // ─── Success ───────────────────────────────────────────
  static const Color success                = Color(0xFF34C759);
  static const Color successDim             = Color(0xFF1A3320);

  // ─── Outlines ──────────────────────────────────────────
  static const Color outline                = Color(0xFF8F9378);  // html: outline
  static const Color outlineVariant         = Color(0xFF454932);  // html: outline-variant

  // ─── Inverse ───────────────────────────────────────────
  static const Color inverseSurface         = Color(0xFFE0E2EA);  // html: inverse-surface
  static const Color inverseOnSurface       = Color(0xFF2D3136);  // html: inverse-on-surface

  // ─── Convenience aliases ───────────────────────────────
  static Color get divider      => Colors.white.withValues(alpha: 0.05);
  static Color get whiteBorder5 => Colors.white.withValues(alpha: 0.05);
  static Color get whiteBorder3 => Colors.white.withValues(alpha: 0.03);

  // ─── Spacing System (8px grid) ─────────────────────────
  static const double space4  = 4;
  static const double space8  = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ─── Border Radius ─────────────────────────────────────
  static const double radiusSmall  = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge  = 16;
  static const double radiusXL     = 24;
  static const double radiusFull   = 999;
}
