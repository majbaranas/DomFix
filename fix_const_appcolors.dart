import 'dart:io';

/// Removes 'const' from widget constructors and expressions that
/// now contain non-const AppColors.xxx references.
///
/// Patterns to fix:
///   const Icon(Icons.xxx, color: AppColors.xxx)
///   const IconThemeData(color: AppColors.xxx)
///   const BorderSide(color: AppColors.xxx)
///   const SizedBox(...child: CircularProgressIndicator(...AppColors...))

void main() async {
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_colors.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_theme.dart'))
      .where((f) => !f.path.contains('theme${Platform.pathSeparator}app_theme_manager.dart'))
      .toList();

  int totalReplacements = 0;
  int filesModified = 0;

  // Regex: find "const <Something>(" where after it, within the same expression, AppColors appears.
  // We handle this by finding lines that have both "const " and "AppColors." and removing the const.
  // But we need to be careful — only remove const from the immediate constructor, not from nested ones.

  for (final file in dartFiles) {
    String content = await file.readAsString();
    final original = content;

    // Pattern 1: const Icon(..., color: AppColors.xxx, ...)
    content = content.replaceAllMapped(
      RegExp(r'const\s+(Icon\([^)]*AppColors\.[^)]*\))'),
      (m) => m.group(1)!,
    );

    // Pattern 2: const IconThemeData(color: AppColors.xxx)
    content = content.replaceAllMapped(
      RegExp(r'const\s+(IconThemeData\([^)]*AppColors\.[^)]*\))'),
      (m) => m.group(1)!,
    );

    // Pattern 3: const BorderSide(color: AppColors.xxx, ...)
    content = content.replaceAllMapped(
      RegExp(r'const\s+(BorderSide\([^)]*AppColors\.[^)]*\))'),
      (m) => m.group(1)!,
    );

    // Pattern 4: const SizedBox(...AppColors...) — complex nested
    content = content.replaceAllMapped(
      RegExp(r'const\s+(SizedBox\([^;]*AppColors\.[^;]*\))'),
      (m) => m.group(1)!,
    );

    // Pattern 5: const LinearGradient / BoxDecoration etc with AppColors
    content = content.replaceAllMapped(
      RegExp(r'const\s+(LinearGradient\([^;]*AppColors\.)'),
      (m) => m.group(1)!,
    );
    content = content.replaceAllMapped(
      RegExp(r'const\s+(BoxDecoration\([^;]*AppColors\.)'),
      (m) => m.group(1)!,
    );

    if (content != original) {
      final replacements = _countDifferences(original, content);
      if (replacements > 0) {
        await file.writeAsString(content);
        totalReplacements += replacements;
        filesModified++;
        print('✅ ${file.path} ($replacements const removals)');
      }
    }
  }

  print('\n🎉 Done! Modified $filesModified files with $totalReplacements total const removals.');
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
