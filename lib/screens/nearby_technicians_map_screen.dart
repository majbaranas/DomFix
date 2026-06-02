import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/technician_location_service.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';
import 'find_pros_screen_content.dart';
import 'technician_profile_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

bool _isOnline(DateTime updatedAt) =>
    DateTime.now().difference(updatedAt).inSeconds <= 10;

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Full-screen OSM map with live Firebase technician pins.
class NearbyTechniciansMapScreen extends StatefulWidget {
  const NearbyTechniciansMapScreen({super.key});

  @override
  State<NearbyTechniciansMapScreen> createState() =>
      _NearbyTechniciansMapScreenState();
}

class _NearbyTechniciansMapScreenState
    extends State<NearbyTechniciansMapScreen> {
  static const _fallback = LatLng(40.758, -73.9855);
  static const _defaultZoom = 14.0;

  final _mapController = MapController();
  final _techService = TechnicianLocationService();
  final _techNotifier = ValueNotifier<List<TechnicianLocation>>([]);

  StreamSubscription<List<TechnicianLocation>>? _techSub;

  LatLng? _userPoint;
  bool _loading = true;
  bool _locating = false;
  TechnicianLocation? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _techSub?.cancel();
    _techNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Location ──────────────────────────────────────────────

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _locating = true;
    });

    LatLng center = _fallback;

    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (serviceOn) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
          center = LatLng(pos.latitude, pos.longitude);
        } else {
          _showMessage('Location permission denied. Showing default area.');
        }
      } else {
        _showMessage('Location services are off. Showing default area.');
      }
    } catch (_) {
      _showMessage('Could not get location. Showing default area.');
    }

    if (!mounted) return;

    _subscribeToTechnicians(center);

    setState(() {
      _userPoint = center;
      _loading = false;
      _locating = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _userPoint != null) {
        _mapController.move(_userPoint!, _defaultZoom);
      }
    });
  }

  Future<void> _recenterOnUser() async {
    HapticFeedback.lightImpact();
    if (_userPoint != null) {
      _mapController.move(_userPoint!, _defaultZoom);
      _mapController.rotate(0); // reset north
    } else {
      await _initLocation();
    }
  }

  void _subscribeToTechnicians(LatLng userPoint) {
    _techSub?.cancel();
    _techSub = _techService
        .nearbyStream(userPoint)
        .listen((list) => _techNotifier.value = list);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Map controls ──────────────────────────────────────────

  void _zoomIn() {
    HapticFeedback.selectionClick();
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _resetNorth() {
    HapticFeedback.selectionClick();
    _mapController.rotate(0);
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const headerHeight = 108.0; // appbar row + search bar + paddings

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Map (or loading state) ──────────────────────
          _loading || _userPoint == null
              ? _buildLoading()
              : _buildMap(safeTop, headerHeight),

          // ── 2. Frosted top overlay: header + search ────────
          _buildTopOverlay(safeTop),

          // ── 3. Right-side controls ─────────────────────────
          if (!_loading && _userPoint != null)
            _buildSideControls(safeTop, safeBottom, headerHeight),

          // ── 4. Bottom technician card ──────────────────────
          if (_selected != null && !_loading)
            _buildPreviewCard(safeBottom),
        ],
      ),
    );
  }

  // ─── Loading ───────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.neonAccent),
          ),
          const SizedBox(height: 16),
          Text('Locating you…',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ─── Map ───────────────────────────────────────────────────

  Widget _buildMap(double safeTop, double headerHeight) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userPoint!,
        initialZoom: _defaultZoom,
        onTap: (_, _) => setState(() => _selected = null),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Dark map tiles (CARTO dark)
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.domfix',
        ),
        // Markers — rotate: true keeps them upright regardless of map rotation.
        ValueListenableBuilder<List<TechnicianLocation>>(
          valueListenable: _techNotifier,
          builder: (_, techs, _) => MarkerLayer(
            // rotate: true counter-rotates each marker to stay screen-aligned
            // when the user rotates the map. The user dot and tech pins will
            // always appear upright, exactly like Google Maps.
            rotate: true,
            markers: [
              Marker(
                point: _userPoint!,
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: const _UserDot(),
              ),
              ...techs.map(
                (t) => Marker(
                  point: t.point,
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = t);
                    },
                    child: _TechPin(selected: _selected?.id == t.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Attribution — bottom-left, minimal
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap © CARTO'),
          ],
          alignment: AttributionAlignment.bottomLeft,
          popupInitialDisplayDuration: Duration.zero,
        ),
      ],
    );
  }

  // ─── Top overlay ───────────────────────────────────────────

  Widget _buildTopOverlay(double safeTop) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: EdgeInsets.fromLTRB(12, safeTop + 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withValues(alpha: 0.78),
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    _OverlayButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    // Title + live count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Technicians',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          ValueListenableBuilder<List<TechnicianLocation>>(
                            valueListenable: _techNotifier,
                            builder: (_, techs, _) {
                              final count = techs.length;
                              return Text(
                                count == 0
                                    ? 'No technicians online nearby'
                                    : '$count technician${count == 1 ? '' : 's'} online',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: count > 0
                                      ? AppColors.neonAccent
                                      : AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Re-center / refresh GPS button
                    _locating
                        ? SizedBox(
                            width: 38,
                            height: 38,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.neonAccent),
                              ),
                            ),
                          )
                        : _OverlayButton(
                            icon: Icons.my_location_rounded,
                            onTap: _recenterOnUser,
                            accent: true,
                          ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search bar — tapping opens Find Pros screen
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FindProsScreenContent()),
                  ),
                  child: Container(
                    height: 44,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181C21).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.neonAccent.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 19,
                            color: AppColors.neonAccent
                                .withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search service or pro…',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.neonAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: AppColors.neonAccent.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Side controls ─────────────────────────────────────────

  Widget _buildSideControls(
      double safeTop, double safeBottom, double headerHeight) {
    final cardOpen = _selected != null;
    return Positioned(
      right: 12,
      bottom: cardOpen ? safeBottom + 230 : safeBottom + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapFab(
            icon: Icons.add_rounded,
            onTap: _zoomIn,
            tooltip: 'Zoom in',
          ),
          const SizedBox(height: 8),
          _MapFab(
            icon: Icons.remove_rounded,
            onTap: _zoomOut,
            tooltip: 'Zoom out',
          ),
          const SizedBox(height: 14),
          _MapFab(
            icon: Icons.explore_rounded,
            onTap: _resetNorth,
            tooltip: 'Reset north',
            small: true,
          ),
        ],
      ),
    );
  }

  // ─── Preview card ──────────────────────────────────────────

  Widget _buildPreviewCard(double safeBottom) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: safeBottom + 12,
      child: _TechPreviewCard(
        tech: _selected!,
        userPoint: _userPoint!,
        onClose: () => setState(() => _selected = null),
      ),
    );
  }
}

// ─── Overlay button ───────────────────────────────────────────────────────────

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accent
              ? AppColors.neonAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(
            color: accent
                ? AppColors.neonAccent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: accent ? AppColors.neonAccent : AppColors.onSurface,
        ),
      ),
    );
  }
}

// ─── Floating action button (map controls) ────────────────────────────────────

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
    this.small = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 36.0 : 42.0;
    final iconSize = small ? 16.0 : 20.0;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF181C21).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(icon,
                  size: iconSize, color: AppColors.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── User location dot (pulsing, rotation-stable) ─────────────────────────────

class _UserDot extends StatefulWidget {
  const _UserDot();

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 1.0, end: 2.4).animate(curved);
    _opacity = Tween<double>(begin: 0.55, end: 0.0).animate(curved);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing ring
              Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonAccent
                        .withValues(alpha: _opacity.value),
                  ),
                ),
              ),
              // Accuracy halo
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonAccent.withValues(alpha: 0.12),
                ),
              ),
              // Core dot
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonAccent,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonAccent.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Technician pin ───────────────────────────────────────────────────────────

class _TechPin extends StatelessWidget {
  const _TechPin({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? AppColors.neonAccent.withValues(alpha: 0.15)
              : AppColors.surfaceContainerHighest,
          border: Border.all(
            color: AppColors.neonAccent
                .withValues(alpha: selected ? 0.9 : 0.45),
            width: selected ? 2.5 : 1.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.neonAccent.withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Icon(Icons.engineering_rounded,
            color: AppColors.neonAccent, size: 20),
      ),
    );
  }
}

// ─── Technician preview card ──────────────────────────────────────────────────

class _TechPreviewCard extends StatelessWidget {
  const _TechPreviewCard({
    required this.tech,
    required this.userPoint,
    required this.onClose,
  });

  final TechnicianLocation tech;
  final LatLng userPoint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final online = _isOnline(tech.updatedAt);
    final dist = TechnicianLocationService.distanceKmPublic(
        userPoint, tech.point);
    final shortId = tech.id.length >= 6 ? tech.id.substring(0, 6) : tech.id;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1218).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: avatar, name/status, distance, close
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              AppColors.neonAccent.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.engineering_rounded,
                        color: AppColors.neonAccent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technician $shortId',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                                shape: BoxShape.circle,
                                color: online
                                    ? AppColors.success
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                boxShadow: online
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success
                                              .withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              online ? 'Online' : 'Offline',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: online
                                    ? AppColors.success
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '·',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.3)),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.near_me_rounded,
                                size: 12,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 3),
                            Text(
                              '${dist.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Last seen
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(
                      'Last seen ${_timeAgo(tech.updatedAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      label: 'Profile',
                      icon: Icons.person_outline_rounded,
                      outlined: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TechnicianProfileScreen(
                            technicianId: tech.id,
                            initialName: 'Technician $shortId',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _CardButton(
                      label: 'Message',
                      icon: Icons.chat_rounded,
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: tech.id,
                            otherUserName: 'Technician $shortId',
                            otherUserRole: 'technician',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card action button ───────────────────────────────────────────────────────

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.neonAccent
              : outlined
                  ? Colors.transparent
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled
                ? AppColors.neonAccent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? AppColors.onPrimary : AppColors.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
