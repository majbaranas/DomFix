import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../models/smart_device.dart';
import '../../../theme/app_colors.dart';

class EnvironmentCard extends StatelessWidget {
  const EnvironmentCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  final SmartDevice device;
  final VoidCallback onTap;

  String? get _lottieAsset {
    switch (device.type) {
      case SmartDeviceType.temperature:
        return 'assets/images/Thermometer.json';
      case SmartDeviceType.humidity:
        return 'assets/images/humidite.json';
      case SmartDeviceType.brightness:
        return 'assets/images/sun.json';
      default:
        return null;
    }
  }

  Color get _iconColor {
    switch (device.type) {
      case SmartDeviceType.temperature:
        return const Color(0xFFFF512F);
      case SmartDeviceType.humidity:
        return const Color(0xFF00C9FF);
      case SmartDeviceType.brightness:
        return const Color(0xFFFDC830);
      default:
        return AppColors.neonAccent;
    }
  }

  List<Color> get _gradientColors {
    switch (device.type) {
      case SmartDeviceType.temperature:
        return [const Color(0x33FF512F), Colors.transparent];
      case SmartDeviceType.humidity:
        return [const Color(0x3300C9FF), Colors.transparent];
      case SmartDeviceType.brightness:
        return [const Color(0x33FDC830), Colors.transparent];
      default:
        return [AppColors.neonAccent.withValues(alpha: 0.15), Colors.transparent];
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = device.value?.toStringAsFixed(1) ?? '--';
    final unit = device.unit ?? '';
    final lottieFile = _lottieAsset;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.whiteBorder5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle background lottie if we wanted, but let's keep it clean
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lottieFile != null)
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: Lottie.asset(lottieFile, fit: BoxFit.contain),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              device.type.getIcon(true),
                              color: _iconColor,
                              size: 20,
                            ),
                          ),
                        if (!device.isOnline)
                          Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.error),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              unit,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
