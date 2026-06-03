import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_colors.dart';
import '../../services/technician_location_service.dart';

class LiveMapWidget extends StatefulWidget {
  final VoidCallback onMapTap;
  final List<Map<String, dynamic>>? nearbyJobs;

  const LiveMapWidget({
    super.key,
    required this.onMapTap,
    this.nearbyJobs,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> with SingleTickerProviderStateMixin {
  late MapController mapController;
  late AnimationController _markerController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    mapController.dispose();
    _markerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.space20),
      child: GestureDetector(
        onTap: onMapTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
            border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonAccent.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Map background
              Container(
                height: 280,
                color: AppColors.surfaceContainerHigh,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(37.7749, -122.4194), // San Francisco (demo)
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                      tileProvider: NetworkTileProvider(),
                    ),
                    // Animated technician marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: const LatLng(37.7749, -122.4194),
                          width: 40,
                          height: 40,
                          child: AnimatedBuilder(
                            animation: _markerController,
                            builder: (context, _) {
                              final scale = 1.0 + (_markerController.value * 0.15);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.neonAccent,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neonAccent.withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.onPrimary,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Sample nearby job markers
                        Marker(
                          point: const LatLng(37.7759, -122.4200),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.cyan.withValues(alpha: 0.8),
                              border: Border.all(color: Colors.cyan, width: 2),
                            ),
                            child: const Icon(
                              Icons.work_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        Marker(
                          point: const LatLng(37.7739, -122.4185),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purple.withValues(alpha: 0.8),
                              border: Border.all(color: Colors.purple, width: 2),
                            ),
                            child: const Icon(
                              Icons.work_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Overlay gradient
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.3),
                      AppColors.background.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),

              // Info section on top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppColors.space16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withValues(alpha: 0.8),
                        AppColors.background.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nearby Requests',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.neonAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '3 active',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neonAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Call-to-action button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppColors.space16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.background.withValues(alpha: 0.9),
                        AppColors.background.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: AppColors.neonAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap to view all nearby requests',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.neonAccent, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
