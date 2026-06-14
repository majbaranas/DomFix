import 'dart:io';

void main() async {
  final file = File('lib/screens/technician_profile_screen.dart');
  var content = await file.readAsString();

  if (!content.contains("import '../theme/app_styles.dart';")) {
    content = content.replaceFirst(
      "import '../theme/app_colors.dart';",
      "import '../theme/app_colors.dart';\nimport '../theme/app_styles.dart';\nimport '../theme/app_spacing.dart';"
    );
  }

  // 1. Top Bar
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.titleMedium.copyWith(fontSize: 16)"
  );

  // 2. Hero Section
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.titleLarge"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.onSurface)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodySmall.copyWith(color: AppColors.onSurfaceVariant)"
  );

  // 3. Bio Section
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.titleMedium.copyWith(fontSize: 16)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(height: 1.6, color: AppColors.onSurfaceVariant)"
  );

  // 4. Portfolio Section
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)",
    "style: AppStyles.caption.copyWith(color: Colors.white)"
  );

  // 5. Reviews Section
  content = content.replaceAll(
    "decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider))",
    "decoration: AppStyles.standardCardDecoration.copyWith(borderRadius: BorderRadius.circular(12))"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.caption"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, height: 1.5, color: AppColors.onSurfaceVariant)",
    "style: AppStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant)"
  );

  // 6. Action Bar Buttons
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)",
    "style: AppStyles.buttonText.copyWith(color: AppColors.onSurface)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onPrimary)",
    "style: AppStyles.buttonText"
  );

  // 7. Skeletons & Errors
  content = content.replaceAll(
    "style: GoogleFonts.inter()",
    "style: AppStyles.bodyMedium"
  );
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)",
    "style: AppStyles.titleLarge.copyWith(fontSize: 20)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onPrimary)",
    "style: AppStyles.buttonText"
  );
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.neonAccent)",
    "style: AppStyles.titleLarge.copyWith(fontSize: 36, color: AppColors.neonAccent)"
  );
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neonAccent)",
    "style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.neonAccent)"
  );

  // 8. _StatCard
  content = content.replaceAll(
    "style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neonAccent)",
    "style: AppStyles.titleMedium.copyWith(color: AppColors.neonAccent)"
  );

  // 9. _ProfileBadge
  content = content.replaceAll(
    "style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)",
    "style: AppStyles.caption.copyWith(fontSize: 10, color: color)"
  );

  await file.writeAsString(content);
  print('✅ technician_profile_screen.dart refactored successfully.');
}
