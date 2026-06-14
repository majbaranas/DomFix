import 'dart:io';

void main() async {
  final file = File('lib/widgets/dashboard/analytics_card.dart');
  String content = await file.readAsString();

  content = content.replaceAll('this.accentColor = AppColors.neonAccent,', 'this.accentColor,');
  content = content.replaceAll('final Color accentColor;', 'final Color? accentColor;');
  content = content.replaceAll('Widget build(BuildContext context) {', 'Widget build(BuildContext context) {\n    final effectiveAccentColor = accentColor ?? AppColors.neonAccent;');
  content = content.replaceAll('color: accentColor.withValues', 'color: effectiveAccentColor.withValues');
  content = content.replaceAll('color: accentColor)', 'color: effectiveAccentColor)');
  content = content.replaceAll('color: accentColor,', 'color: effectiveAccentColor,');

  await file.writeAsString(content);
  print('Fixed analytics card.');
}
