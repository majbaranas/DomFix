import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dPaint = Paint()
      ..color = AppColors.onSurface.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fPaint = Paint()
      ..color = AppColors.neonAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.2);
    path.lineTo(size.width * 0.55, size.height * 0.2);
    path.cubicTo(
      size.width * 0.7, size.height * 0.2,
      size.width * 0.8, size.height * 0.3,
      size.width * 0.8, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.8, size.height * 0.7,
      size.width * 0.7, size.height * 0.8,
      size.width * 0.55, size.height * 0.8,
    );
    path.lineTo(size.width * 0.3, size.height * 0.8);
    path.lineTo(size.width * 0.3, size.height * 0.2);
    canvas.drawPath(path, dPaint);

    final fPath = Path();
    fPath.moveTo(size.width * 0.3, size.height * 0.2);
    fPath.lineTo(size.width * 0.3, size.height * 0.8);
    fPath.moveTo(size.width * 0.3, size.height * 0.5);
    fPath.lineTo(size.width * 0.65, size.height * 0.5);
    fPath.moveTo(size.width * 0.3, size.height * 0.2);
    fPath.lineTo(size.width * 0.7, size.height * 0.2);
    canvas.drawPath(fPath, fPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
