import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../models/smart_device.dart';
import '../../services/iot_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/smart_home/device_control_sheet.dart';
import '../../widgets/smart_home/environment_card.dart';
import '../../widgets/smart_home/smart_device_card.dart';
import '../../widgets/smart_home/smart_home_search.dart';
import '../../widgets/smart_home/voice_command_overlay.dart';
import 'smart_home/activity_log_screen.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> with SingleTickerProviderStateMixin {
  final _iot = IoTService.instance;

  String _selectedRoom = 'All Rooms';
  late AnimationController _statusPulseController;

  @override
  void initState() {
    super.initState();
    _statusPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _statusPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildVoiceFab(),
      body: SafeArea(
        child: StreamBuilder<List<SmartDevice>>(
          stream: _iot.devicesStream(),
          builder: (context, snapshot) {
            final devices = snapshot.data ?? [];
            final sensors = devices.where((d) => d.isSensor).toList();
            final controllables = devices.where((d) => !d.isSensor).toList();
            final filteredDevices = _selectedRoom == 'All Rooms'
                ? controllables
                : controllables.where((d) => SmartRoom.fromString(d.room).label == _selectedRoom).toList();

            final availableRooms = {'All Rooms'};
            for (var d in controllables) {
              availableRooms.add(SmartRoom.fromString(d.room).label);
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(
                  devices.where((d) => d.isOnline).length,
                  devices.length,
                ),


                // Room Filter
                if (controllables.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: _buildRoomFilter(availableRooms.toList()),
                    ),
                  ),

                // Quick Actions (Smart Assistant Area replacement)
                SliverToBoxAdapter(
                  child: _buildQuickActions(),
                ),

                // Environment Section
                if (sensors.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          Text(
                            'Environment',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.neonAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.neonAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Live',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.neonAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: sensors.length,
                        itemBuilder: (context, index) {
                          return EnvironmentCard(
                            device: sensors[index],
                            onTap: () => _openDeviceSheet(sensors[index]),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Devices Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          'Devices',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${controllables.where((d) => d.isOn).length} active',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (filteredDevices.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final device = filteredDevices[index];
                          return SmartDeviceCard(
                            device: device,
                            onToggle: (val) => _iot.toggleDevice(device.id, val),
                            onTap: () => _openDeviceSheet(device),
                          );
                        },
                        childCount: filteredDevices.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(int onlineCount, int totalCount) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      pinned: true,
      elevation: 0,
      expandedHeight: 110,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Home',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              StreamBuilder<bool>(
                stream: _iot.connectionStatusStream,
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  return Row(
                    children: [
                      AnimatedBuilder(
                        animation: _statusPulseController,
                        builder: (context, child) {
                          return Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? AppColors.success : AppColors.error,
                              boxShadow: [
                                BoxShadow(
                                  color: (isConnected ? AppColors.success : AppColors.error).withValues(alpha: 0.5),
                                  blurRadius: 6 * _statusPulseController.value,
                                  spreadRadius: 2 * _statusPulseController.value,
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      Text(
                        isConnected ? 'Connected' : 'Offline',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Search
        IconButton(
          icon: Icon(Icons.search_rounded, color: AppColors.onSurface),
          onPressed: () async {
            final devices = await _iot.devicesStream().first;
            if (!mounted) return;
            final selected = await showSearch(
              context: context,
              delegate: SmartHomeSearchDelegate(devices),
            );
            if (selected != null && mounted) _openDeviceSheet(selected);
          },
        ),
        SizedBox(width: 8),
        // More actions menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: AppColors.onSurface),
          offset: const Offset(0, 40),
          color: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (val) async {
            if (val == 'history') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ActivityLogScreen()),
              );
            } else if (val == 'demo') {
              await _iot.toggleDemoMode();
              setState(() {});
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'demo',
              child: Row(
                children: [
                  Icon(
                    _iot.isDemoMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: AppColors.neonAccent,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Demo Mode',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'history',
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 12),
                  Text(
                    'Activity Log',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          SizedBox(
            height: 120, // Taller for premium cards
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              children: [
                QuickActionCard(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Turn All Lights ON',
                  color: const Color(0xFFFDC830), // Yellow
                  onTap: () => _iot.setAllDevicesOfType('light', true),
                ),
                QuickActionCard(
                  icon: Icons.nightlight_round,
                  label: 'Turn All Lights OFF',
                  color: Colors.grey,
                  onTap: () => _iot.setAllDevicesOfType('light', false),
                ),
                QuickActionCard(
                  icon: Icons.meeting_room_rounded,
                  label: 'Open All Doors',
                  color: const Color(0xFF00C9FF), // Cyan
                  onTap: () => _iot.setAllDevicesOfType('door', true),
                ),
                QuickActionCard(
                  icon: Icons.door_front_door_rounded,
                  label: 'Close All Doors',
                  color: Colors.brown,
                  onTap: () => _iot.setAllDevicesOfType('door', false),
                ),
                QuickActionCard(
                  icon: Icons.mode_night_rounded,
                  label: 'Night Mode',
                  color: Colors.indigoAccent,
                  onTap: () => _iot.activateMode('Night Mode'),
                ),
                QuickActionCard(
                  icon: Icons.directions_walk_rounded,
                  label: 'Away Mode',
                  color: Colors.redAccent,
                  onTap: () => _iot.activateMode('Away Mode'),
                ),
                QuickActionCard(
                  icon: Icons.eco_rounded,
                  label: 'Energy Saving',
                  color: Colors.green,
                  onTap: () => _iot.activateMode('Energy Saving'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomFilter(List<String> rooms) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          final isSelected = _selectedRoom == room;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                room,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                ),
              ),
              selected: isSelected,
              onSelected: (s) {
                if (s) setState(() => _selectedRoom = room);
              },
              backgroundColor: AppColors.surfaceContainerLow,
              selectedColor: AppColors.neonAccent,
              side: BorderSide(
                color: isSelected ? AppColors.neonAccent : AppColors.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 48,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No devices yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Turn on Demo mode to see sample devices, or add devices in Firebase RTDB.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDeviceSheet(SmartDevice device) {
    DeviceControlSheet.show(context, device.id);
  }

  Widget _buildVoiceFab() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.glassHighlight,
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            HapticFeedback.lightImpact();
            VoiceCommandOverlay.show(context);
          },
          child: const Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
