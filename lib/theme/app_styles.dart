import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_manager.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// DomFix Unified Design System
///
/// This file defines the exact typography, shadow, and radius standards
/// to ensure pixel-perfect consistency across both Light and Dark themes.
class AppStyles {
  AppStyles._();

  // ─── Shadows ─────────────────────────────────────────────────────────────
  
  /// Very subtle, soft shadow for Light Mode cards to avoid the "dirty" look.
  /// Harder, distinct glow for Dark Mode.
  static List<BoxShadow> get cardShadow {
    final isDark = AppThemeManager.instance.isDarkMode;
    return [
      if (isDark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          offset: const Offset(0, 8),
        )
      else
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04), // Slate 900 at 4%
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      if (!isDark)
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.02), // Slate 900 at 2%
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
    ];
  }

  /// Elevated shadow for floating elements (Bottom Nav, Bottom Sheets, Dialogs).
  static List<BoxShadow> get elevatedShadow {
    final isDark = AppThemeManager.instance.isDarkMode;
    return [
      if (isDark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          blurRadius: 32,
          offset: const Offset(0, -8),
        )
      else
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
    ];
  }

  // ─── Typography Hierarchy ────────────────────────────────────────────────
  
  /// Massive titles (e.g., Home screen greeting)
  static TextStyle get titleLarge => GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
        letterSpacing: -0.5,
      );

  /// Standard section headers (e.g., "Top Technicians", "My Devices")
  static TextStyle get titleMedium => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
        letterSpacing: -0.3,
      );

  /// Standard body text
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  /// Subdued body text / descriptions
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
      );

  /// Button text (Primary calls to action)
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onPrimary,
      );

  /// Overlines / Captions
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.5,
      );

  // ─── Card Decoration Standards ───────────────────────────────────────────

  /// Standard Box Decoration for primary UI Cards (Expert Card, Service Card, etc.)
  static BoxDecoration get standardCardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge), // 18px
        border: Border.all(color: AppColors.divider),
        boxShadow: cardShadow,
      );

  // ─── Button Standards ────────────────────────────────────────────────────

  /// Primary Action Button (Solid Neon Green)
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonAccent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium), // 12px
        ),
        textStyle: buttonText,
      );

  /// Secondary Action Button (Subtle background, distinct text)
  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerHigh,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium), // 12px
        ),
        textStyle: buttonText,
      );

  // ─── Navigation Standards ────────────────────────────────────────────────

  /// Standard Bottom Navigation Bar appearance
  static BoxDecoration get bottomNavDecoration => BoxDecoration(
        color: AppColors.surface,
        boxShadow: elevatedShadow,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      );

  // ─── Empty & Loading State Standards ─────────────────────────────────────

  /// Standard Empty State Container
  static Widget emptyState({
    required IconData icon,
    required String title,
    required String description,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: standardCardDecoration.copyWith(
        boxShadow: [], // No shadow for empty states
        color: AppColors.surfaceContainerLowest, // Slightly flatter background
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(title, style: titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(description, style: bodySmall, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 24),
            action,
          ],
        ],
      ),
    );
  }

  /// Standard Loading Indicator
  static Widget loadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonAccent),
      ),
    );
  }
}
