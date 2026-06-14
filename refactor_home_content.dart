import 'dart:io';

void main() async {
  final file = File('lib/screens/home_screen_content.dart');
  var content = await file.readAsString();

  // 1. Add imports
  if (!content.contains("import '../theme/app_styles.dart';")) {
    content = content.replaceFirst(
      "import '../theme/app_colors.dart';",
      "import '../theme/app_colors.dart';\nimport '../theme/app_styles.dart';\nimport '../theme/app_spacing.dart';"
    );
  }

  // 2. Fix ambient glow to be clean in light mode
  content = content.replaceAll(
    "colors: [Color(0x18CDF200), Color(0x00000000)],",
    "colors: [AppThemeManager.instance.isDarkMode ? const Color(0x18D9FF00) : Colors.transparent, Colors.transparent],"
  );

  // 3. Fix header background
  content = content.replaceAll(
    "color: AppColors.surface.withValues(alpha: 0.7),",
    "color: AppThemeManager.instance.isDarkMode ? AppColors.surface.withValues(alpha: 0.7) : AppColors.background.withValues(alpha: 0.9),"
  );
  content = content.replaceAll(
    "bottom: BorderSide(color: AppColors.glassBorder),",
    "bottom: BorderSide(color: AppColors.divider),"
  );

  // 4. Typography Replacements
  // Greeting text
  content = content.replaceAll(
    "style: GoogleFonts.inter(\n                        fontSize: 12,\n                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),\n                      ),",
    "style: AppStyles.bodySmall,"
  );
  
  // Username text
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n                        fontSize: 18,\n                        fontWeight: FontWeight.w700,\n                        color: AppColors.onSurface,\n                        letterSpacing: -0.3,\n                      ),",
    "style: AppStyles.titleLarge,"
  );

  // Fallback Avatar text
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n          fontSize: 18,\n          fontWeight: FontWeight.w700,\n          color: AppColors.neonAccent,\n        ),",
    "style: AppStyles.titleMedium.copyWith(color: AppColors.neonAccent),"
  );

  // Search text
  content = content.replaceAll(
    "style: GoogleFonts.inter(\n                  fontSize: 14,\n                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),\n                ),",
    "style: AppStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),"
  );

  // Section title
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n        fontSize: 18,\n        fontWeight: FontWeight.w700,\n        color: AppColors.onSurface,\n        letterSpacing: -0.4,\n      ),",
    "style: AppStyles.titleMedium,"
  );

  // 5. Card Standardizations
  // Search bar
  content = content.replaceAll(
    "decoration: BoxDecoration(\n            color: AppColors.surface,\n            borderRadius: BorderRadius.circular(14),\n            border: Border.all(color: AppColors.divider),\n          ),",
    "decoration: AppStyles.standardCardDecoration.copyWith(borderRadius: BorderRadius.circular(AppSpacing.radiusMedium), boxShadow: []),"
  );

  // Empty devices card
  content = content.replaceAll(
    "decoration: BoxDecoration(\n                      color: AppColors.surface,\n                      borderRadius: BorderRadius.circular(18),\n                      border: Border.all(color: AppColors.divider),\n                    ),",
    "decoration: AppStyles.standardCardDecoration,"
  );

  // Empty devices text
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n                                  fontSize: 14,\n                                  fontWeight: FontWeight.w700,\n                                  color: AppColors.onSurface,\n                                ),",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),"
  );

  // Add device button
  content = content.replaceAll(
    "decoration: BoxDecoration(\n                          color: AppColors.surface,\n                          borderRadius: BorderRadius.circular(18),\n                          border: Border.all(\n                            color: AppColors.neonAccent.withValues(alpha: 0.3),\n                            width: 1,\n                          ),\n                        ),",
    "decoration: AppStyles.standardCardDecoration.copyWith(border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3), width: 1)),"
  );

  // Device card
  content = content.replaceAll(
    "decoration: BoxDecoration(\n                        color: AppColors.surface,\n                        borderRadius: BorderRadius.circular(18),\n                        border: Border.all(\n                          color: isOn\n                              ? AppColors.neonAccent.withValues(alpha: 0.25)\n                              : AppColors.divider,\n                        ),\n                      ),",
    "decoration: AppStyles.standardCardDecoration.copyWith(border: Border.all(color: isOn ? AppColors.neonAccent.withValues(alpha: 0.25) : AppColors.divider)),"
  );

  // Loading device cards
  content = content.replaceAll(
    "decoration: BoxDecoration(\n            color: AppColors.surface,\n            borderRadius: BorderRadius.circular(18),\n            border: Border.all(color: AppColors.divider),\n          ),",
    "decoration: AppStyles.standardCardDecoration,"
  );

  // Map banner
  content = content.replaceAll(
    "decoration: BoxDecoration(\n            color: AppColors.surface,\n            borderRadius: BorderRadius.circular(18),\n            border: Border.all(color: AppColors.divider),\n          ),",
    "decoration: AppStyles.standardCardDecoration,"
  );
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n                        fontSize: 14,\n                        fontWeight: FontWeight.w700,\n                        color: AppColors.onSurface,\n                      ),",
    "style: AppStyles.titleMedium,"
  );

  // Technician Card
  content = content.replaceAll(
    "decoration: BoxDecoration(\n          color: AppColors.surface,\n          borderRadius: BorderRadius.circular(20),\n          border: Border.all(color: AppColors.divider),\n        ),",
    "decoration: AppStyles.standardCardDecoration.copyWith(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge + 2)),"
  );
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n                fontSize: 15,\n                fontWeight: FontWeight.w600,\n                color: AppColors.onSurface,\n                letterSpacing: -0.3,\n              ),",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),"
  );

  // Recent Chat Tile
  content = content.replaceAll(
    "decoration: BoxDecoration(\n              color: AppColors.surface,\n              borderRadius: BorderRadius.circular(16),\n              border: Border.all(color: AppColors.divider),\n            ),",
    "decoration: AppStyles.standardCardDecoration,"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(\n                          fontSize: 14,\n                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,\n                          color: AppColors.onSurface,\n                        ),",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600),"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(\n                          fontSize: 12,\n                          color: unread > 0\n                              ? AppColors.onSurface\n                              : AppColors.onSurfaceVariant.withValues(alpha: 0.7),\n                        ),",
    "style: AppStyles.bodySmall.copyWith(color: unread > 0 ? AppColors.onSurface : AppColors.onSurfaceVariant.withValues(alpha: 0.7)),"
  );

  await file.writeAsString(content);
  print('✅ home_screen_content.dart refactored successfully.');
}
