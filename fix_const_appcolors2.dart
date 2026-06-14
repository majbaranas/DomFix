import 'dart:io';

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

  for (final file in dartFiles) {
    String content = await file.readAsString();
    final original = content;

    // Pattern: const SnackBar
    content = content.replaceAllMapped(
      RegExp(r'const\s+(SnackBar\([^;]*AppColors\.[^;]*\))', multiLine: true),
      (m) => m.group(1)!,
    );

    // Pattern: const Center
    content = content.replaceAllMapped(
      RegExp(r'const\s+(Center\([^;]*AppColors\.[^;]*\))', multiLine: true),
      (m) => m.group(1)!,
    );

    // Pattern: const UnderlineInputBorder
    content = content.replaceAllMapped(
      RegExp(r'const\s+(UnderlineInputBorder\([^)]*AppColors\.[^)]*\))', multiLine: true),
      (m) => m.group(1)!,
    );

    // Pattern: const Border(
    content = content.replaceAllMapped(
      RegExp(r'const\s+(Border\([^)]*AppColors\.[^)]*\))', multiLine: true),
      (m) => m.group(1)!,
    );

    // Pattern: const SizedBox(
    content = content.replaceAllMapped(
      RegExp(r'const\s+(SizedBox\([^;]*AppColors\.[^;]*\))', multiLine: true),
      (m) => m.group(1)!,
    );

    // Pattern: const Padding(
    content = content.replaceAllMapped(
      RegExp(r'const\s+(Padding\([^;]*AppColors\.[^;]*\))', multiLine: true),
      (m) => m.group(1)!,
    );
    
    // Pattern: const priorities = [
    content = content.replaceAll('const priorities = [', 'final priorities = [');

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
