import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/smart_device.dart';
import '../../../services/iot_service.dart';
import '../../../theme/app_colors.dart';

class DeviceControlSheet extends StatefulWidget {
  const DeviceControlSheet({super.key, required this.deviceId});

  final String deviceId;

  static void show(BuildContext context, String deviceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceControlSheet(deviceId: deviceId),
    );
  }

  @override
  State<DeviceControlSheet> createState() => _DeviceControlSheetState();
}

class _DeviceControlSheetState extends State<DeviceControlSheet> {
  double? _localBrightness;
  double? _localSpeed;
  bool _isDragging = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onBrightnessChanged(double val) {
    setState(() => _localBrightness = val);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      IoTService.instance.changeDeviceValue(widget.deviceId, val, valueKey: 'brightness');
    });
  }

  void _onSpeedChanged(double val) {
    setState(() => _localSpeed = val);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      IoTService.instance.changeDeviceValue(widget.deviceId, val, valueKey: 'speed');
    });
  }

  Color _getDeviceColor(SmartDevice device) {
    if (!device.isOn && !device.isSensor) return AppColors.onSurfaceVariant;
    switch (device.type) {
      case SmartDeviceType.light:
      case SmartDeviceType.brightness:
        return AppColors.neonAccent;
      case SmartDeviceType.fan:
      case SmartDeviceType.ac:
        return const Color(0xFF00C9FF);
      case SmartDeviceType.door:
      case SmartDeviceType.garage:
      case SmartDeviceType.lock:
        return AppColors.warning;
      case SmartDeviceType.temperature:
      case SmartDeviceType.heater:
        return const Color(0xFFFF512F);
      case SmartDeviceType.humidity:
        return const Color(0xFF00C9FF);
      default:
        return AppColors.neonAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SmartDevice?>(
      stream: IoTService.instance.deviceStream(widget.deviceId),
      builder: (context, snapshot) {
        final device = snapshot.data;
        if (device == null) {
          return const SizedBox.shrink(); // Might have been deleted
        }

        // Sync local state if not dragging
        if (!_isDragging) {
          _localBrightness = device.brightness;
          _localSpeed = device.speed;
        }

        final dColor = _getDeviceColor(device);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                  color: AppColors.whiteBorder5,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: device.isOn 
                              ? dColor.withValues(alpha: 0.15) 
                              : AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          device.type.getIcon(device.isOn),
                          color: dColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${SmartRoom.fromString(device.room).label} • ${device.statusText}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (device.type.isControllable)
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            value: device.isOn,
                            activeTrackColor: dColor,
                            onChanged: device.isOnline
                                ? (val) => IoTService.instance.toggleDevice(widget.deviceId, val)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Content
                _buildContent(context, device, dColor),
                // Safe area padding
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SmartDevice device, Color dColor) {
    if (device.isSensor) {
      return _buildSensorContent(device, dColor);
    }
    
    switch (device.type) {
      case SmartDeviceType.light:
        return _buildLightContent(device, dColor);
      case SmartDeviceType.fan:
        return _buildFanContent(device, dColor);
      case SmartDeviceType.door:
      case SmartDeviceType.garage:
        return _buildDoorContent(device, dColor);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Text(
            'Basic controls only for this device type.',
            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
          ),
        );
    }
  }

  Widget _buildSensorContent(SmartDevice device, Color dColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.whiteBorder5),
        ),
        child: Column(
          children: [
            Text(
              device.type.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  device.value?.toStringAsFixed(1) ?? '--',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  device.unit ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: dColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightContent(SmartDevice device, Color dColor) {
    final displayValue = _localBrightness ?? device.brightness ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brightness',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${(displayValue * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.brightness_low_rounded, color: AppColors.onSurfaceVariant),
              SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: dColor,
                      inactiveTrackColor: AppColors.surfaceContainerHigh,
                      thumbColor: Colors.white,
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                    ),
                    child: Slider(
                      value: displayValue,
                      onChangeStart: (_) => setState(() => _isDragging = true),
                      onChanged: device.isOn && device.isOnline
                          ? _onBrightnessChanged
                          : null,
                      onChangeEnd: device.isOn && device.isOnline
                          ? (val) {
                              setState(() => _isDragging = false);
                              IoTService.instance.changeDeviceValue(widget.deviceId, val, valueKey: 'brightness');
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.brightness_high_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFanContent(SmartDevice device, Color dColor) {
    final displayValue = _localSpeed ?? device.speed ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fan Speed',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${(displayValue * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.wind_power_outlined, color: AppColors.onSurfaceVariant),
              SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: dColor,
                      inactiveTrackColor: AppColors.surfaceContainerHigh,
                      thumbColor: Colors.white,
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                    ),
                    child: Slider(
                      value: displayValue,
                      onChangeStart: (_) => setState(() => _isDragging = true),
                      onChanged: device.isOn && device.isOnline
                          ? _onSpeedChanged
                          : null,
                      onChangeEnd: device.isOn && device.isOnline
                          ? (val) {
                              setState(() => _isDragging = false);
                              IoTService.instance.changeDeviceValue(widget.deviceId, val, valueKey: 'speed');
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.cyclone_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoorContent(SmartDevice device, Color dColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: device.isOnline ? () => IoTService.instance.toggleDevice(device.id, !device.isOn) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: device.isOn ? dColor.withValues(alpha: 0.15) : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: device.isOn ? dColor.withValues(alpha: 0.3) : AppColors.divider,
            ),
          ),
          child: Column(
            children: [
              Icon(
                device.isOn ? Icons.meeting_room_outlined : Icons.door_front_door_outlined,
                size: 64,
                color: device.isOn ? dColor : AppColors.onSurfaceVariant,
              ),
              SizedBox(height: 24),
              Text(
                device.isOn ? 'Tap to Close' : 'Tap to Open',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: device.isOn ? dColor : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
