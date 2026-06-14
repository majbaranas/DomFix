import 'dart:io';

void main() async {
  final file = File('lib/theme/app_colors.dart');
  final content = await file.readAsString();
  final lines = content.split('\n');
  
  final out = <String>[];
  out.add("import 'package:flutter/material.dart';");
  out.add("import 'app_theme_manager.dart';");
  out.add("import 'app_spacing.dart';");
  out.add("");
  out.add("class AppColors {");
  out.add("  AppColors._();");
  
  final lightMap = {
    'background': 'Color(0xFFF8FAFC)',
    'surface': 'Color(0xFFFFFFFF)',
    'surfaceDim': 'Color(0xFFFFFFFF)',
    'surfaceBright': 'Color(0xFFFFFFFF)',
    'surfaceContainerLowest': 'Color(0xFFFFFFFF)',
    'surfaceContainerLow': 'Color(0xFFF1F5F9)',
    'surfaceContainer': 'Color(0xFFF8FAFC)',
    'surfaceContainerHigh': 'Color(0xFFF1F5F9)',
    'surfaceContainerHighest': 'Color(0xFFE2E8F0)',
    'surfaceVariant': 'Color(0xFFF1F5F9)',
    'onSurface': 'Color(0xFF0F172A)',
    'onSurfaceVariant': 'Color(0xFF64748B)',
    'onBackground': 'Color(0xFF0F172A)',
    'primaryContainer': 'Color(0xFF00E5A8)',
    'neonAccent': 'Color(0xFF00E5A8)',
    'primaryFixed': 'Color(0xFF00E5A8)',
    'primaryFixedDim': 'Color(0xFF00E5A8)',
    'onPrimary': 'Color(0xFFFFFFFF)',
    'onPrimaryFixed': 'Color(0xFFFFFFFF)',
    'onPrimaryContainer': 'Color(0xFFFFFFFF)',
    'inversePrimary': 'Color(0xFF00E5A8)',
    'surfaceTint': 'Color(0xFF00E5A8)',
    'secondary': 'Color(0xFF00B8FF)',
    'secondaryContainer': 'Color(0xFFE0F2FE)',
    'onSecondary': 'Color(0xFFFFFFFF)',
    'secondaryFixed': 'Color(0xFF00B8FF)',
    'secondaryFixedDim': 'Color(0xFF00B8FF)',
    'onSecondaryContainer': 'Color(0xFF0369A1)',
    'onSecondaryFixed': 'Color(0xFFFFFFFF)',
    'onSecondaryFixedVariant': 'Color(0xFFFFFFFF)',
    'tertiaryContainer': 'Color(0xFFF1F5F9)',
    'onTertiary': 'Color(0xFF0F172A)',
    'onTertiaryContainer': 'Color(0xFF64748B)',
    'error': 'Color(0xFFEF4444)',
    'errorContainer': 'Color(0xFFFEE2E2)',
    'onError': 'Color(0xFFFFFFFF)',
    'onErrorContainer': 'Color(0xFFB91C1C)',
    'emergency': 'Color(0xFFEF4444)',
    'warning': 'Color(0xFFF59E0B)',
    'success': 'Color(0xFF10B981)',
    'successDim': 'Color(0xFF059669)',
    'outline': 'Color(0xFFE2E8F0)',
    'outlineVariant': 'Color(0xFFCBD5E1)',
    'inverseSurface': 'Color(0xFF0F172A)',
    'inverseOnSurface': 'Color(0xFFF8FAFC)',
    'lowPriority': 'Color(0xFF10B981)',
    'mediumPriority': 'Color(0xFF00B8FF)',
    'highPriority': 'Color(0xFFF59E0B)',
    'statusPending': 'Color(0xFFF59E0B)',
    'statusAccepted': 'Color(0xFF00B8FF)',
    'statusOnTheWay': 'Color(0xFF3B82F6)',
    'statusInProgress': 'Color(0xFF8B5CF6)',
    'statusCompleted': 'Color(0xFF10B981)',
    'statusCancelled': 'Color(0xFFEF4444)',
    'shimmerBase': 'Color(0xFFF1F5F9)',
    'shimmerHighlight': 'Color(0xFFFFFFFF)',
  };

  final colorRe = RegExp(r'static\s+const\s+Color\s+(\w+)\s*=\s*(Color\([^)]+\));');
  final getterRe = RegExp(r'static\s+Color\s+get\s+(\w+)\s*=>\s*(.*);');

  for (final line in lines) {
    if (line.contains('static const double')) continue;
    if (line.contains('class AppColors') || line.contains('AppColors._();') || line.startsWith('import ')) continue;
    
    final cm = colorRe.firstMatch(line);
    if (cm != null) {
      final name = cm.group(1)!;
      final darkVal = cm.group(2)!;
      final lightVal = lightMap[name] ?? darkVal;
      out.add("  static Color get $name => AppThemeManager.instance.isDarkMode ? $darkVal : $lightVal;");
      continue;
    }
    
    final gm = getterRe.firstMatch(line);
    if (gm != null) {
      final name = gm.group(1)!;
      final darkVal = gm.group(2)!;
      if (['divider', 'whiteBorder5', 'whiteBorder3', 'glassBackground', 'glassBorder', 'glassHighlight'].contains(name)) {
        if (name.toLowerCase().contains('glass') || name.toLowerCase().contains('border') || name.toLowerCase().contains('divider')) {
          final lightVal = 'Colors.black.withValues(alpha: 0.05)';
          out.add("  static Color get $name => AppThemeManager.instance.isDarkMode ? $darkVal : $lightVal;");
        } else {
          out.add("  static Color get $name => $darkVal;");
        }
      }
      continue;
    }
    
    if (line.trim().startsWith('//')) {
      out.add(line);
    }
  }

  out.add("}");

  await file.writeAsString(out.join('\n'));
  print('Rewrote app_colors.dart');
}
