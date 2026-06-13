import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/smart_device.dart';
import '../../../theme/app_colors.dart';

class SmartDeviceCard extends StatelessWidget {
  const SmartDeviceCard({
    super.key,
    required this.device,
    required this.onToggle,
    required this.onTap,
  });

  final SmartDevice device;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = device.isOn || (device.isSensor && device.isOnline);
    final isOnline = device.isOnline;

    // Apple Home style: Pure white when active, dark grey when inactive
    final bgColor = isActive ? Colors.white : AppColors.surfaceContainerHigh;
    final textColor = isActive ? Colors.black : Colors.white;
    final subTextColor = isActive ? Colors.black54 : Colors.white60;
    
    // Single accent for icons (amber for lights, otherwise black/white)
    Color iconColor;
    if (!isActive) {
      iconColor = Colors.white54;
    } else {
      if (device.type == SmartDeviceType.light || device.type == SmartDeviceType.brightness) {
        iconColor = Colors.amber;
      } else {
        iconColor = Colors.black;
      }
    }

    return GestureDetector(
      onTap: () {
        if (!device.isSensor && isOnline) {
          onToggle(!device.isOn);
        } else {
          onTap();
        }
      },
      onLongPress: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  device.type.getIcon(device.isOn),
                  color: iconColor,
                  size: 28,
                ),
                if (!isOnline)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8, right: 4),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.destructiveRed,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? device.statusText : 'Off',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
