import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/smart_device.dart';
import '../services/iot_service.dart';
import '../theme/app_colors.dart';
import '../widgets/scroll_reveal.dart';

/// Professional Smart Home Screen
/// Production-ready UI for controlling ESP32 IoT devices
class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _iot = IoTService.instance;
  String _selectedRoom = 'all';
  bool _showSensors = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildRoomFilter(),
            Expanded(child: _buildDeviceGrid()),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Home',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<List<SmartDevice>>(
                  stream: _iot.devicesStream(),
                  builder: (_, snap) {
                    final devices = snap.data ?? [];
                    final online = devices.where((d) => d.isOnline).length;
                    return Text(
                      '$online/${devices.length} devices online',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: Icons.power_settings_new_rounded,
          onTap: () async {
            HapticFeedback.mediumImpact();
            await _iot.turnAllOff();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All devices turned off',
                      style: GoogleFonts.inter(color: AppColors.onPrimary)),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _buildRoomFilter() {
    final rooms = ['all', ...SmartRoom.values.map((r) => r.key)];
    
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final room = rooms[i];
          final isSelected = _selectedRoom == room;
          final label = room == 'all'
              ? 'All'
              : SmartRoom.fromString(room).label;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedRoom = room);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.neonAccent
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.neonAccent
                      : AppColors.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (room != 'all') ...[
                    Icon(
                      SmartRoom.fromString(room).icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceGrid() {
    return StreamBuilder<List<SmartDevice>>(
      stream: _selectedRoom == 'all'
          ? _iot.devicesStream()
          : _iot.devicesByRoom(_selectedRoom),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.neonAccent,
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildError('Error loading devices');
        }

        final devices = snapshot.data ?? [];
        
        if (devices.isEmpty) {
          return _buildEmpty();
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: devices.length,
          itemBuilder: (_, i) => RevealItem(
            delay: Duration(milliseconds: i * 40 > 200 ? 200 : i * 40),
            child: _DeviceCard(
              device: devices[i],
              onTap: () => _toggleDevice(devices[i]),
              onLongPress: () => _showDeviceDetails(devices[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(
                Icons.devices_other_rounded,
                size: 44,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No devices yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first smart device\nto get started',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showAddDeviceSheet,
      backgroundColor: AppColors.neonAccent,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        'Add Device',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _toggleDevice(SmartDevice device) async {
    if (!device.type.isControllable) return;
    
    HapticFeedback.mediumImpact();
    await _iot.toggleDevice(device.id, !device.isOn);
  }

  void _showDeviceDetails(SmartDevice device) {
    // TODO: Show detailed device control screen
    HapticFeedback.lightImpact();
  }

  void _showAddDeviceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddDeviceSheet(),
    );
  }
}

/// Device Card Widget
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.onLongPress,
  });

  final SmartDevice device;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isOn = device.isOn;
    final isOnline = device.isOnline;
    final isSensor = !device.type.isControllable;

    return GestureDetector(
      onTap: device.type.isControllable ? onTap : onLongPress,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn && isOnline
                ? AppColors.neonAccent.withValues(alpha: 0.3)
                : AppColors.divider,
            width: isOn && isOnline ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isOn && isOnline
                        ? AppColors.neonAccent.withValues(alpha: 0.15)
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    device.type.getIcon(isOn),
                    size: 26,
                    color: isOn && isOnline
                        ? AppColors.neonAccent
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppColors.success
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              device.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            if (isSensor && device.value != null) ...[
              Text(
                '${device.value!.toStringAsFixed(1)}${device.unit ?? ''}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonAccent,
                ),
              ),
            ] else ...[
              Text(
                isOnline ? (isOn ? 'On' : 'Off') : 'Offline',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isOnline
                      ? (isOn ? AppColors.neonAccent : AppColors.onSurfaceVariant)
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add Device Bottom Sheet
class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _nameController = TextEditingController();
  final _esp32Controller = TextEditingController();
  SmartDeviceType _selectedType = SmartDeviceType.light;
  SmartRoom _selectedRoom = SmartRoom.livingRoom;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _esp32Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final device = SmartDevice(
      id: '',
      name: name,
      room: _selectedRoom.key,
      type: _selectedType,
      isOnline: true,
      isOn: false,
      lastUpdated: DateTime.now(),
      esp32Id: _esp32Controller.text.trim().isEmpty
          ? null
          : _esp32Controller.text.trim(),
    );

    await IoTService.instance.addDevice(device);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Smart Device',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: 'Device Name',
              hint: 'e.g. Living Room Light',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _esp32Controller,
              label: 'ESP32 ID (Optional)',
              hint: 'e.g. ESP32_RELAY1',
            ),
            const SizedBox(height: 20),
            Text(
              'Device Type',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SmartDeviceType.values
                  .take(10) // Show most common types
                  .map((type) => _TypeChip(
                        type: type,
                        selected: _selectedType == type,
                        onTap: () => setState(() => _selectedType = type),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Room',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SmartRoom.values
                  .map((room) => _RoomChip(
                        room: room,
                        selected: _selectedRoom == room,
                        onTap: () => setState(() => _selectedRoom = room),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _saving
                        ? AppColors.neonAccent.withValues(alpha: 0.5)
                        : AppColors.neonAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Add Device',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimary,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SmartDeviceType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.neonAccent : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.neonAccent : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type.iconOff,
              size: 16,
              color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomChip extends StatelessWidget {
  const _RoomChip({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final SmartRoom room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.neonAccent : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.neonAccent : AppColors.divider,
          ),
        ),
        child: Text(
          room.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
