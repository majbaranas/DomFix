import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_device.dart';
import '../theme/app_colors.dart';
import '../widgets/scroll_reveal.dart';

/// Smart Control — user's registered home devices.
/// Data lives at `users/{uid}/devices/{deviceId}` in Firestore.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});
  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _devicesRef;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _devicesRef = _fs.collection('users').doc(uid).collection('devices');
    }
  }

  Stream<List<UserDevice>> _devicesStream() {
    if (_devicesRef == null) return const Stream.empty();
    return _devicesRef!
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(UserDevice.fromDoc).toList());
  }

  Future<void> _addDevice(UserDevice device) async {
    await _devicesRef?.add(device.toMap());
  }

  Future<void> _toggleStatus(UserDevice device) async {
    HapticFeedback.lightImpact();
    final next = device.status == DeviceStatus.online
        ? DeviceStatus.offline
        : DeviceStatus.online;
    await _devicesRef?.doc(device.id).update({'status': next.key});
  }

  Future<void> _deleteDevice(UserDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Device',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${device.name}" from your home?',
          style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _devicesRef?.doc(device.id).delete();
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDeviceSheet(onAdd: _addDevice),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.neonAccent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
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
                  'Smart Control',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage your connected devices',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<List<UserDevice>>(
            stream: _devicesStream(),
            builder: (_, snap) {
              final devices = snap.data ?? [];
              final online =
                  devices.where((d) => d.status == DeviceStatus.online).length;
              if (devices.isEmpty) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.neonAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.neonAccent.withValues(alpha: 0.6),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$online online',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neonAccent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<List<UserDevice>>(
      stream: _devicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.neonAccent, strokeWidth: 2),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading devices',
                style:
                    GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          );
        }
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: devices.length,
          itemBuilder: (_, i) => RevealItem(
            delay: Duration(milliseconds: i * 60 > 240 ? 240 : i * 60),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceCard(
                device: devices[i],
                onToggle: () => _toggleStatus(devices[i]),
                onDelete: () => _deleteDevice(devices[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(
                Icons.settings_remote_rounded,
                size: 36,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No devices yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first home device and start tracking it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.neonAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.onPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add a device',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Device card ─────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onToggle,
    required this.onDelete,
  });

  final UserDevice device;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  Color get _statusColor {
    return switch (device.status) {
      DeviceStatus.online => AppColors.success,
      DeviceStatus.warning => const Color(0xFFFFB800),
      DeviceStatus.offline => AppColors.onSurfaceVariant.withValues(alpha: 0.3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isOn = device.status == DeviceStatus.online;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOn
              ? AppColors.neonAccent.withValues(alpha: 0.2)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isOn
                  ? AppColors.neonAccent.withValues(alpha: 0.12)
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: isOn
                  ? Border.all(
                      color: AppColors.neonAccent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Icon(
              device.type.icon,
              size: 24,
              color: isOn
                  ? AppColors.neonAccent
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                    color: AppColors.success
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.type.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.3)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOn ? 'Online' : 'Offline',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Toggle switch
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isOn
                    ? AppColors.neonAccent
                    : AppColors.surfaceContainerHigh,
                border: Border.all(
                  color: isOn
                      ? AppColors.neonAccent
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment:
                    isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.onPrimary : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add device bottom sheet ─────────────────────────────────
class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({required this.onAdd});
  final Future<void> Function(UserDevice) onAdd;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _nameController = TextEditingController();
  DeviceType _selectedType = DeviceType.other;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final device = UserDevice(
      id: '',
      name: name,
      type: _selectedType,
      status: DeviceStatus.online,
      createdAt: DateTime.now(),
    );
    await widget.onAdd(device);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add Device',
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
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Device Name',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'e.g. Living Room AC',
              hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          Text('Device Type',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: DeviceType.values
                .map((t) => _TypeChip(
                      type: t,
                      selected: _selectedType == t,
                      onTap: () => setState(() => _selectedType = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
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
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.type, required this.selected, required this.onTap});
  final DeviceType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonAccent
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.neonAccent
                : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon,
                size: 16,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
