import re

with open('lib/theme/app_colors.dart', 'r') as f:
    content = f.read()

lines = content.split('\n')
out = []
out.append("import 'package:flutter/material.dart';")
out.append("import 'app_theme_manager.dart';")
out.append("import 'app_spacing.dart';")
out.append("")
out.append("class AppColors {")
out.append("  AppColors._();")

light_map = {
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
}

color_re = re.compile(r'static\s+const\s+Color\s+(\w+)\s*=\s*(Color\([^)]+\));')
getter_re = re.compile(r'static\s+Color\s+get\s+(\w+)\s*=>\s*(.*);')

for line in lines:
    if 'static const double' in line:
        continue
    if 'class AppColors' in line or 'AppColors._();' in line or 'import ' in line:
        continue
        
    m = color_re.search(line)
    if m:
        name = m.group(1)
        dark_val = m.group(2)
        light_val = light_map.get(name, dark_val)
        out.append(f"  static Color get {name} => AppThemeManager.instance.isDarkMode ? {dark_val} : {light_val};")
        continue
        
    m = getter_re.search(line)
    if m:
        name = m.group(1)
        dark_val = m.group(2)
        if name in ['divider', 'whiteBorder5', 'whiteBorder3', 'glassBackground', 'glassBorder', 'glassHighlight']:
            if 'glass' in name.lower() or 'border' in name.lower() or 'divider' in name.lower():
                light_val = 'Colors.black.withValues(alpha: 0.05)'
                out.append(f"  static Color get {name} => AppThemeManager.instance.isDarkMode ? {dark_val} : {light_val};")
            else:
                out.append(f"  static Color get {name} => {dark_val};")
        continue
        
    if line.strip().startswith('//'):
        out.append(line)

out.append("}")

with open('lib/theme/app_colors.dart', 'w') as f:
    f.write('\n'.join(out))

print('Rewrote app_colors.dart')
