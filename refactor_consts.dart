import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int modifiedFiles = 0;

  for (final file in files) {
    String content = await file.readAsString();
    bool modified = false;

    // 1. Replace AppColors.space... with AppSpacing.space...
    if (content.contains('AppColors.space') || content.contains('AppColors.radius')) {
      content = content.replaceAll('AppColors.space', 'AppSpacing.space');
      content = content.replaceAll('AppColors.radius', 'AppSpacing.radius');
      modified = true;
      
      // we need to add import for app_spacing.dart if AppColors is imported
      if (!content.contains('app_spacing.dart') && content.contains('app_colors.dart')) {
        content = content.replaceAll(
          "import 'package:domfix/theme/app_colors.dart';", 
          "import 'package:domfix/theme/app_colors.dart';\nimport 'package:domfix/theme/app_spacing.dart';"
        );
        // Also relative imports
        content = content.replaceAllMapped(
          RegExp(r"import '([^']*)app_colors\.dart';"),
          (m) => "import '${m.group(1)}app_colors.dart';\nimport '${m.group(1)}app_spacing.dart';"
        );
      }
    }

    // 2. Remove const before widgets/objects using AppColors properties (which are no longer const)
    // Common patterns:
    // const Icon(..., color: AppColors.x)
    // const TextStyle(..., color: AppColors.x)
    // const BoxDecoration(..., color: AppColors.x)
    // const BorderSide(..., color: AppColors.x)
    
    // We can do a simpler approach: finding 'const ' and looking ahead to the end of the statement or parentheses
    // to see if AppColors is used (and it's not AppSpacing).
    // A regex to replace 'const ' when followed by some text, 'AppColors.', and NOT 'AppSpacing' within the same parenthesis block is hard.
    
    // Let's do some common explicit replacements:
    final patterns = [
      RegExp(r'const\s+Icon\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+TextStyle\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+BoxDecoration\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+BorderSide\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+Divider\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+CircularProgressIndicator\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+LinearProgressIndicator\s*\(([^)]*AppColors\.[a-zA-Z0-9_]+[^)]*)\)'),
      RegExp(r'const\s+Text\s*\([^)]*style:\s*AppColors\.[a-zA-Z0-9_]+[^)]*\)'),
    ];

    for (final p in patterns) {
      if (p.hasMatch(content)) {
        content = content.replaceAllMapped(p, (m) {
          final fullMatch = m.group(0)!;
          return fullMatch.replaceFirst('const ', '');
        });
        modified = true;
      }
    }

    // A more aggressive generic replace for 'const Widget( ... AppColors.xxx ...)' where there is no nested parenthesis parsing.
    // We'll just run flutter analyze after and fix the remaining ones.

    if (modified) {
      await file.writeAsString(content);
      modifiedFiles++;
    }
  }

  print('Modified $modifiedFiles files.');
}
