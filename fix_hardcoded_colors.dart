import 'dart:io';

/// This script replaces hardcoded dark-mode colors with AppColors references
/// so that the UI adapts to Light/Dark theme automatically.
///
/// Categories of replacements:
/// 1. Hardcoded hex Color(0xFF...) -> AppColors.xxx
/// 2. Colors.white.withValues(alpha: X) -> AppColors.glassBorder / glassBackground etc
/// 3. const Color(0xFF...) patterns that need const removal since AppColors are not const

void main() async {
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Don't touch the theme files themselves or main.dart
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_colors.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_theme.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_theme_manager.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_spacing.dart'))
      .toList();

  int totalReplacements = 0;
  int filesModified = 0;

  for (final file in dartFiles) {
    String content = await file.readAsString();
    final original = content;
    bool needsAppColorsImport = false;

    // ──────────────────────────────────────────────────
    // STEP 1: Replace hardcoded hex colors with AppColors
    // ──────────────────────────────────────────────────

    // Background colors
    content = content.replaceAll("const Color(0xFF070B14)", "AppColors.background");
    content = content.replaceAll("Color(0xFF070B14)", "AppColors.background");

    // Surface colors
    content = content.replaceAll("const Color(0xFF101419)", "AppColors.surface");
    content = content.replaceAll("Color(0xFF101419)", "AppColors.surface");

    // Surface container low
    content = content.replaceAll("const Color(0xFF0A0E13)", "AppColors.surfaceContainerLowest");
    content = content.replaceAll("Color(0xFF0A0E13)", "AppColors.surfaceContainerLowest");

    // Surface container high
    content = content.replaceAll("const Color(0xFF1A2233)", "AppColors.surfaceContainerHigh");
    content = content.replaceAll("Color(0xFF1A2233)", "AppColors.surfaceContainerHigh");
    content = content.replaceAll("const Color(0xFF121826)", "AppColors.surfaceContainerLow");
    content = content.replaceAll("Color(0xFF121826)", "AppColors.surfaceContainerLow");

    // Surface container
    content = content.replaceAll("const Color(0xFF1C2025)", "AppColors.surfaceContainer");
    content = content.replaceAll("Color(0xFF1C2025)", "AppColors.surfaceContainer");

    // Surface bright
    content = content.replaceAll("const Color(0xFF36393F)", "AppColors.surfaceBright");
    content = content.replaceAll("Color(0xFF36393F)", "AppColors.surfaceBright");

    // Neon Accent
    content = content.replaceAll("const Color(0xFFD9FF00)", "AppColors.neonAccent");
    content = content.replaceAll("Color(0xFFD9FF00)", "AppColors.neonAccent");

    // Primary Container
    content = content.replaceAll("const Color(0xFFCDF200)", "AppColors.primaryContainer");
    content = content.replaceAll("Color(0xFFCDF200)", "AppColors.primaryContainer");

    // On Surface (text)
    content = content.replaceAll("const Color(0xFFE0E2EA)", "AppColors.onSurface");
    content = content.replaceAll("Color(0xFFE0E2EA)", "AppColors.onSurface");

    // On Primary
    content = content.replaceAll("const Color(0xFF2B3400)", "AppColors.onPrimary");
    content = content.replaceAll("Color(0xFF2B3400)", "AppColors.onPrimary");

    // Error
    content = content.replaceAll("const Color(0xFFFFB4AB)", "AppColors.error");
    content = content.replaceAll("Color(0xFFFFB4AB)", "AppColors.error");
    content = content.replaceAll("const Color(0xFFFF4D4D)", "AppColors.emergency");
    content = content.replaceAll("Color(0xFFFF4D4D)", "AppColors.emergency");
    content = content.replaceAll("const Color(0xFFFF6B6B)", "AppColors.statusCancelled");
    content = content.replaceAll("Color(0xFFFF6B6B)", "AppColors.statusCancelled");

    // Warning
    content = content.replaceAll("const Color(0xFFFFB84D)", "AppColors.warning");
    content = content.replaceAll("Color(0xFFFFB84D)", "AppColors.warning");

    // Success
    content = content.replaceAll("const Color(0xFF34C759)", "AppColors.success");
    content = content.replaceAll("Color(0xFF34C759)", "AppColors.success");

    // Secondary
    content = content.replaceAll("const Color(0xFF00B8FF)", "AppColors.secondary");
    content = content.replaceAll("Color(0xFF00B8FF)", "AppColors.secondary");

    // Outlines
    content = content.replaceAll("const Color(0xFF8F9378)", "AppColors.outline");
    content = content.replaceAll("Color(0xFF8F9378)", "AppColors.outline");
    content = content.replaceAll("const Color(0xFF454932)", "AppColors.outlineVariant");
    content = content.replaceAll("Color(0xFF454932)", "AppColors.outlineVariant");

    // ──────────────────────────────────────────────────
    // STEP 2: Replace Colors.white.withValues(alpha: X) with AppColors equivalents
    // These are used for glassmorphism / border effects on dark backgrounds
    // In light mode, they need to become black-based instead
    // ──────────────────────────────────────────────────

    // Borders (alpha 0.03 to 0.08) -> AppColors.glassBorder
    content = content.replaceAll("Colors.white.withValues(alpha: 0.03)", "AppColors.whiteBorder3");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.04)", "AppColors.glassBackground");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.05)", "AppColors.whiteBorder5");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.06)", "AppColors.glassBorder");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.08)", "AppColors.glassBorder");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.10)", "AppColors.glassHighlight");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.1)", "AppColors.glassHighlight");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.12)", "AppColors.glassHighlight");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.2)", "AppColors.glassHighlight");

    // Text opacity patterns - map to onSurface with appropriate variants
    content = content.replaceAll("Colors.white.withValues(alpha: 0.4)", "AppColors.onSurfaceVariant");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.5)", "AppColors.onSurfaceVariant");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.6)", "AppColors.onSurfaceVariant");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.7)", "AppColors.onSurface");
    content = content.replaceAll("Colors.white.withValues(alpha: 0.9)", "AppColors.onSurface");

    // ──────────────────────────────────────────────────
    // STEP 3: Add AppColors import if file was modified and doesn't have it
    // ──────────────────────────────────────────────────

    if (content != original) {
      // Check if import already exists
      if (!content.contains("import") || 
          (!content.contains("app_colors.dart") && content.contains("AppColors"))) {
        needsAppColorsImport = true;
      }

      if (needsAppColorsImport) {
        // Find the right import path based on file location
        final filePath = file.path.replaceAll('\\', '/');
        final depth = filePath.split('lib/').last.split('/').length - 1;
        final prefix = List.filled(depth, '..').join('/');
        final importStatement = "import '$prefix/theme/app_colors.dart';\n";
        
        // Insert after last import
        final importRegex = RegExp(r"^import\s+[^;]+;\s*$", multiLine: true);
        final matches = importRegex.allMatches(content).toList();
        if (matches.isNotEmpty) {
          final lastImportEnd = matches.last.end;
          // Only add if not already there
          if (!content.contains("app_colors.dart")) {
            content = content.substring(0, lastImportEnd) + 
                      '\n' + importStatement +
                      content.substring(lastImportEnd);
          }
        }
      }

      final replacements = _countDifferences(original, content);
      if (replacements > 0) {
        await file.writeAsString(content);
        totalReplacements += replacements;
        filesModified++;
        print('✅ ${file.path} ($replacements replacements)');
      }
    }
  }

  print('\n🎉 Done! Modified $filesModified files with $totalReplacements total replacements.');
}

int _countDifferences(String a, String b) {
  final linesA = a.split('\n');
  final linesB = b.split('\n');
  int diffs = 0;
  final maxLen = linesA.length > linesB.length ? linesA.length : linesB.length;
  for (int i = 0; i < maxLen; i++) {
    final lineA = i < linesA.length ? linesA[i] : '';
    final lineB = i < linesB.length ? linesB[i] : '';
    if (lineA != lineB) diffs++;
  }
  return diffs;
}
