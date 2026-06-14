import 'package:flutter/material.dart';
import 'app_theme_manager.dart';
import 'app_spacing.dart';

class AppColors {
  AppColors._();
/// DomFix Design System — Premium Dark UI
///
/// Pixel-accurate color mapping from the HTML/Tailwind reference design.
/// High contrast, intentional accent usage, consistent spacing, zero visual noise.
  // ─── Core Surfaces (from HTML design) ─────────────────
  static Color get background => AppThemeManager.instance.isDarkMode ? Color(0xFF070B14) : Color(0xFFF8FAFC);
  static Color get surface => AppThemeManager.instance.isDarkMode ? Color(0xFF101419) : Color(0xFFFFFFFF);
  static Color get surfaceDim => AppThemeManager.instance.isDarkMode ? Color(0xFF101419) : Color(0xFFFFFFFF);
  static Color get surfaceBright => AppThemeManager.instance.isDarkMode ? Color(0xFF36393F) : Color(0xFFFFFFFF);
  static Color get surfaceContainerLowest => AppThemeManager.instance.isDarkMode ? Color(0xFF0A0E13) : Color(0xFFFFFFFF);
  static Color get surfaceContainerLow => AppThemeManager.instance.isDarkMode ? Color(0xFF121826) : Color(0xFFF1F5F9);
  static Color get surfaceContainer => AppThemeManager.instance.isDarkMode ? Color(0xFF1C2025) : Color(0xFFF8FAFC);
  static Color get surfaceContainerHigh => AppThemeManager.instance.isDarkMode ? Color(0xFF1A2233) : Color(0xFFF1F5F9);
  static Color get surfaceContainerHighest => AppThemeManager.instance.isDarkMode ? Color(0xFF31353B) : Color(0xFFE2E8F0);
  static Color get surfaceVariant => AppThemeManager.instance.isDarkMode ? Color(0xFF31353B) : Color(0xFFF1F5F9);
  // ─── On Surface (Text) ─────────────────────────────────
  static Color get onSurface => AppThemeManager.instance.isDarkMode ? Color(0xFFE0E2EA) : Color(0xFF0F172A);
  static Color get onSurfaceVariant => AppThemeManager.instance.isDarkMode ? Color(0xFFC5C9AC) : Color(0xFF64748B);
  static Color get onBackground => AppThemeManager.instance.isDarkMode ? Color(0xFFE0E2EA) : Color(0xFF0F172A);
  // ─── Primary / Neon Accent ─────────────────────────────
  static Color get primaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFFCDF200) : Color(0xFFCDF200);
  static Color get neonAccent => AppThemeManager.instance.isDarkMode ? Color(0xFFD9FF00) : Color(0xFFD9FF00);
  static Color get primaryFixed => AppThemeManager.instance.isDarkMode ? Color(0xFFCDF200) : Color(0xFFCDF200);
  static Color get primaryFixedDim => AppThemeManager.instance.isDarkMode ? Color(0xFFB4D400) : Color(0xFFB4D400);
  static Color get onPrimary => AppThemeManager.instance.isDarkMode ? Color(0xFF2B3400) : Color(0xFF181E00);
  static Color get onPrimaryFixed => AppThemeManager.instance.isDarkMode ? Color(0xFF181E00) : Color(0xFFFFFFFF);
  static Color get onPrimaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFF5A6B00) : Color(0xFFFFFFFF);
  static Color get inversePrimary => AppThemeManager.instance.isDarkMode ? Color(0xFF556500) : Color(0xFF556500);
  static Color get surfaceTint => AppThemeManager.instance.isDarkMode ? Color(0xFFB4D400) : Color(0xFFB4D400);
  // ─── Secondary ─────────────────────────────────────────
  static Color get secondary => AppThemeManager.instance.isDarkMode ? Color(0xFFC2C6D6) : Color(0xFF00B8FF);
  static Color get secondaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFF444956) : Color(0xFFE0F2FE);
  static Color get onSecondary => AppThemeManager.instance.isDarkMode ? Color(0xFF2B303D) : Color(0xFFFFFFFF);
  static Color get secondaryFixed => AppThemeManager.instance.isDarkMode ? Color(0xFFDEE2F3) : Color(0xFF00B8FF);
  static Color get secondaryFixedDim => AppThemeManager.instance.isDarkMode ? Color(0xFFC2C6D6) : Color(0xFF00B8FF);
  static Color get onSecondaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFFB4B8C8) : Color(0xFF0369A1);
  static Color get onSecondaryFixed => AppThemeManager.instance.isDarkMode ? Color(0xFF161B27) : Color(0xFFFFFFFF);
  static Color get onSecondaryFixedVariant => AppThemeManager.instance.isDarkMode ? Color(0xFF424754) : Color(0xFFFFFFFF);
  // ─── Tertiary ──────────────────────────────────────────
  static Color get tertiaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFFCEE6F2) : Color(0xFFF1F5F9);
  static Color get onTertiary => AppThemeManager.instance.isDarkMode ? Color(0xFF1C333D) : Color(0xFF0F172A);
  static Color get onTertiaryContainer => AppThemeManager.instance.isDarkMode ? Color(0xFF516872) : Color(0xFF64748B);
  // ─── Error ─────────────────────────────────────────────
  static Color get error => AppThemeManager.instance.isDarkMode ? Color(0xFFFFB4AB) : Color(0xFFEF4444);
  static Color get errorContainer => AppThemeManager.instance.isDarkMode ? Color(0xFF93000A) : Color(0xFFFEE2E2);
  static Color get onError => AppThemeManager.instance.isDarkMode ? Color(0xFF690005) : Color(0xFFFFFFFF);
  static Color get onErrorContainer => AppThemeManager.instance.isDarkMode ? Color(0xFFFFDAD6) : Color(0xFFB91C1C);
  static Color get emergency => AppThemeManager.instance.isDarkMode ? Color(0xFFFF4D4D) : Color(0xFFEF4444);
  static Color get warning => AppThemeManager.instance.isDarkMode ? Color(0xFFFFB84D) : Color(0xFFF59E0B);
  // ─── Success ───────────────────────────────────────────
  static Color get success => AppThemeManager.instance.isDarkMode ? Color(0xFF34C759) : Color(0xFF10B981);
  static Color get successDim => AppThemeManager.instance.isDarkMode ? Color(0xFF1A3320) : Color(0xFF059669);
  // ─── Outlines ──────────────────────────────────────────
  static Color get outline => AppThemeManager.instance.isDarkMode ? Color(0xFF8F9378) : Color(0xFFE2E8F0);
  static Color get outlineVariant => AppThemeManager.instance.isDarkMode ? Color(0xFF454932) : Color(0xFFCBD5E1);
  // ─── Inverse ───────────────────────────────────────────
  static Color get inverseSurface => AppThemeManager.instance.isDarkMode ? Color(0xFFE0E2EA) : Color(0xFF0F172A);
  static Color get inverseOnSurface => AppThemeManager.instance.isDarkMode ? Color(0xFF2D3136) : Color(0xFFF8FAFC);
  // ─── Convenience aliases ───────────────────────────────
  static Color get divider => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
  static Color get whiteBorder5 => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
  static Color get whiteBorder3 => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05);
  // ─── Spacing System (8px grid) ─────────────────────────
  // ─── Border Radius ─────────────────────────────────────
  // ─── Priority / Urgency Colors ─────────────────────────
  static Color get lowPriority => AppThemeManager.instance.isDarkMode ? Color(0xFF4ECDC4) : Color(0xFF10B981);
  static Color get mediumPriority => AppThemeManager.instance.isDarkMode ? Color(0xFF79CFFF) : Color(0xFF00B8FF);
  static Color get highPriority => AppThemeManager.instance.isDarkMode ? Color(0xFFFFB84D) : Color(0xFFF59E0B);
  // emergency is already defined above as Color(0xFFFF4D4D)
  // ─── Booking Status Colors ─────────────────────────────
  static Color get statusPending => AppThemeManager.instance.isDarkMode ? Color(0xFFFFB84D) : Color(0xFFF59E0B);
  static Color get statusAccepted => AppThemeManager.instance.isDarkMode ? Color(0xFF4ECDC4) : Color(0xFF00B8FF);
  static Color get statusOnTheWay => AppThemeManager.instance.isDarkMode ? Color(0xFF79CFFF) : Color(0xFF3B82F6);
  static Color get statusInProgress => AppThemeManager.instance.isDarkMode ? Color(0xFF9E9BFF) : Color(0xFF8B5CF6);
  static Color get statusCompleted => AppThemeManager.instance.isDarkMode ? Color(0xFF34C759) : Color(0xFF10B981);
  static Color get statusCancelled => AppThemeManager.instance.isDarkMode ? Color(0xFFFF6B6B) : Color(0xFFEF4444);
  // ─── Glassmorphism ─────────────────────────────────────
  static Color get glassBackground => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.05);
  static Color get glassBorder => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
  static Color get glassHighlight => AppThemeManager.instance.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05);
  // ─── Shimmer / Skeleton ────────────────────────────────
  static Color get shimmerBase => AppThemeManager.instance.isDarkMode ? Color(0xFF1A1E25) : Color(0xFFF1F5F9);
  static Color get shimmerHighlight => AppThemeManager.instance.isDarkMode ? Color(0xFF252A33) : Color(0xFFFFFFFF);
}