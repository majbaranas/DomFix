import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/iot_service.dart';
import '../theme/app_colors.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  final _iot = IoTService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'DomFix Smart Home',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 32),
            StreamBuilder<bool>(
              stream: _iot.ledStateStream,
              builder: (context, snapshot) {
                final isOn = snapshot.data ?? false;
                return _buildDeviceCard(isOn);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: 8),
          Text(
            'FIREBASE CONNECTED',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(bool isOn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOn ? AppColors.onSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isOn ? AppColors.onSurface : AppColors.divider),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isOn ? AppColors.surface.withValues(alpha: 0.15) : AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              size: 28,
              color: isOn ? AppColors.surface : AppColors.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Light',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isOn ? AppColors.surface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isOn ? AppColors.surface.withValues(alpha: 0.7) : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: isOn,
            activeColor: AppColors.neonAccent,
            onChanged: (val) {
              _iot.toggleLed(val);
            },
          ),
        ],
      ),
    );
  }
}
