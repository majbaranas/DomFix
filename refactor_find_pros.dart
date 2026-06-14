import 'dart:io';

void main() async {
  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Refactor find_pros_screen_content.dart
  // ─────────────────────────────────────────────────────────────────────────────
  final file1 = File('lib/screens/find_pros_screen_content.dart');
  var content1 = await file1.readAsString();

  if (!content1.contains("import '../theme/app_styles.dart';")) {
    content1 = content1.replaceFirst(
      "import '../theme/app_colors.dart';",
      "import '../theme/app_colors.dart';\nimport '../theme/app_styles.dart';\nimport '../theme/app_spacing.dart';"
    );
  }

  // Header "Find Pros"
  content1 = content1.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.titleLarge"
  );
  
  // Map Button
  content1 = content1.replaceAll(
    "decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider))",
    "decoration: AppStyles.standardCardDecoration.copyWith(borderRadius: BorderRadius.circular(10), boxShadow: [])"
  );

  // Search Bar
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface)",
    "style: AppStyles.bodyMedium"
  );
  content1 = content1.replaceAll(
    "hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4))",
    "hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant.withValues(alpha: 0.4))"
  );

  // Chips
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,\n                        color: sel ? AppColors.onPrimary : AppColors.onSurfaceVariant)",
    "style: AppStyles.bodySmall.copyWith(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppColors.onPrimary : AppColors.onSurfaceVariant)"
  );

  // Loading / Error
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)"
  );

  // Empty State
  content1 = content1.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.titleMedium"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)"
  );

  // Section Headers
  content1 = content1.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.titleMedium"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neonAccent)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.neonAccent)"
  );

  // _FeaturedCard Material -> Container
  content1 = content1.replaceAll(
    "child: SizedBox(width: 180, child: Material(\n        color: AppColors.surface, borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,",
    "child: SizedBox(width: 180, child: Container(\n        decoration: AppStyles.standardCardDecoration, clipBehavior: Clip.antiAlias,"
  );
  // _FeaturedCard texts
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.caption.copyWith(color: AppColors.onSurface)"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)",
    "style: AppStyles.caption.copyWith(color: AppColors.success, fontSize: 10)"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.caption.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)"
  );

  // _NearbyCard
  content1 = content1.replaceAll(
    "decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider))",
    "decoration: AppStyles.standardCardDecoration"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.neonAccent)",
    "style: AppStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.neonAccent)"
  );
  content1 = content1.replaceAll(
    "style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodySmall"
  );

  await file1.writeAsString(content1);
  print('✅ find_pros_screen_content.dart refactored successfully.');

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Refactor expert_card.dart
  // ─────────────────────────────────────────────────────────────────────────────
  final file2 = File('lib/widgets/expert_card.dart');
  var content2 = await file2.readAsString();

  if (!content2.contains("import '../theme/app_styles.dart';")) {
    content2 = content2.replaceFirst(
      "import '../theme/app_colors.dart';",
      "import '../theme/app_colors.dart';\nimport '../theme/app_styles.dart';\nimport '../theme/app_spacing.dart';"
    );
  }

  // Remove backdrop blur
  content2 = content2.replaceAll(
    "child: BackdropFilter(\n            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),\n            child: AnimatedContainer(",
    "child: AnimatedContainer("
  );
  // Remove the extra closing parenthesis for the removed BackdropFilter
  content2 = content2.replaceAll(
    "          ),\n        ),\n      ),\n    );",
    "        ),\n      ),\n    );"
  );

  // Standardize Card Decoration
  content2 = content2.replaceAll(
    "decoration: BoxDecoration(\n                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),\n                borderRadius: BorderRadius.circular(24),\n                border: Border.all(color: AppColors.glassBorder),\n                boxShadow: [\n                  BoxShadow(\n                    color: Colors.black.withValues(alpha: 0.6),\n                    blurRadius: 32,\n                    offset: const Offset(0, 8),\n                  ),\n                  BoxShadow(\n                    color: AppColors.glassBorder,\n                    blurRadius: 0,\n                    spreadRadius: 0,\n                    offset: const Offset(0, -1),\n                  ),\n                ],\n              ),",
    "decoration: AppStyles.standardCardDecoration.copyWith(borderRadius: BorderRadius.circular(24)),"
  );

  // Name
  content2 = content2.replaceAll(
    "style: GoogleFonts.spaceGrotesk(\n                  fontSize: 15,\n                  fontWeight: FontWeight.w600,\n                  color: Colors.white,\n                  letterSpacing: -0.3,\n                ),",
    "style: AppStyles.titleMedium.copyWith(fontSize: 15, color: AppColors.onSurface),"
  );
  
  // Level
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                  fontSize: 12,\n                  color: AppColors.onSurfaceVariant,\n                ),",
    "style: AppStyles.bodySmall,"
  );

  // Rating
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                  fontSize: 12,\n                  fontWeight: FontWeight.w500,\n                  color: Colors.white,\n                ),",
    "style: AppStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),"
  );
  
  // ETA & Clearance Labels
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                      fontSize: 10,\n                      color: AppColors.onSurfaceVariant,\n                    ),",
    "style: AppStyles.caption,"
  );

  // ETA & Clearance Values
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                      fontSize: 13,\n                      fontWeight: FontWeight.w500,\n                      color: Colors.white,\n                    ),",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),"
  );
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                          fontSize: 13,\n                          fontWeight: FontWeight.w500,\n                          color: Colors.white,\n                        ),",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),"
  );

  // Action Buttons
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                    fontSize: 13,\n                    fontWeight: FontWeight.w600,\n                    color: widget.isAvailable\n                        ? AppColors.onPrimary\n                        : AppColors.onSurfaceVariant,\n                  ),",
    "style: AppStyles.buttonText.copyWith(color: widget.isAvailable ? AppColors.onPrimary : AppColors.onSurfaceVariant, fontSize: 13),"
  );
  content2 = content2.replaceAll(
    "style: GoogleFonts.inter(\n                    fontSize: 13,\n                    fontWeight: FontWeight.w500,\n                    color: Colors.white,\n                  ),",
    "style: AppStyles.buttonText.copyWith(color: AppColors.onSurface, fontSize: 13),"
  );

  // Fix white border issue on light mode
  content2 = content2.replaceAll(
    "border: Border.all(color: AppColors.glassBorder)",
    "border: Border.all(color: AppColors.divider)"
  );
  content2 = content2.replaceAll(
    "border: Border(right: BorderSide(color: AppColors.glassBorder))",
    "border: Border(right: BorderSide(color: AppColors.divider))"
  );
  content2 = content2.replaceAll(
    "border: Border(right: BorderSide(color: AppColors.glassBorder),)",
    "border: Border(right: BorderSide(color: AppColors.divider),)"
  );

  await file2.writeAsString(content2);
  print('✅ expert_card.dart refactored successfully.');
}
