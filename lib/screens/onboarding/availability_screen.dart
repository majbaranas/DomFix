import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/technician_onboarding_data.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 – Availability
// ─────────────────────────────────────────────────────────────────────────────

class AvailabilityScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const AvailabilityScreen({
    super.key,
    required this.onboardingData,
    this.onNext,
    this.onBack,
  });

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen>
    with SingleTickerProviderStateMixin {
  // ── Day definitions ────────────────────────────────────────────────────────
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  // ── State ──────────────────────────────────────────────────────────────────
  late bool _isAvailable;
  late Set<String> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _radiusMiles;
  late String _detectedLocation;
  bool _detectingLocation = false;
  final _mapController = MapController();
  LatLng? _currentLocation;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final d = widget.onboardingData;
    _isAvailable = d.isAvailable;
    _selectedDays = Set.from(d.availableDays);
    _startTime = TimeOfDay(hour: d.startHour, minute: d.startMinute);
    _endTime = TimeOfDay(hour: d.endHour, minute: d.endMinute);
    _radiusMiles = d.serviceRadiusMiles;
    _detectedLocation = d.detectedLocation ?? '25 mile radius active';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _toggleDay(String day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => _timePickerTheme(ctx, child),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Widget _timePickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryContainer,
          onPrimary: const Color(0xFF2B3400),
          surface: const Color(0xFF1C2025),
          onSurface: AppColors.onSurface,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _detectLocation() async {
    HapticFeedback.mediumImpact();
    setState(() => _detectingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _detectingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _detectingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _detectingLocation = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    final previouslyNull = _currentLocation == null;
    setState(() {
      _detectingLocation = false;
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      _detectedLocation = 'Location detected · ${_radiusMiles}mi radius';
    });
    
    if (!previouslyNull) {
      _mapController.move(_currentLocation!, 12);
    }
    HapticFeedback.lightImpact();
  }

  void _handleNext() {
    final d = widget.onboardingData;
    d.isAvailable = _isAvailable;
    d.availableDays = _selectedDays.toList();
    d.startHour = _startTime.hour;
    d.startMinute = _startTime.minute;
    d.endHour = _endTime.hour;
    d.endMinute = _endTime.minute;
    d.serviceRadiusMiles = _radiusMiles;
    d.detectedLocation = _detectedLocation;
    HapticFeedback.mediumImpact();
    widget.onNext?.call();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  children: [
                    _buildProgress(),
                    const SizedBox(height: 28),
                    _buildActiveStatusCard(),
                    const SizedBox(height: 28),
                    _buildWeeklySchedule(),
                    const SizedBox(height: 28),
                    _buildTimeRange(),
                    const SizedBox(height: 32),
                    _buildServiceRadius(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back,
                  color: AppColors.primaryContainer, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text('DOMFIX_CORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer, fontWeight: FontWeight.w800,
              fontSize: 18, letterSpacing: 1,
            )),
          const Spacer(),
          Icon(Icons.more_vert, color: AppColors.onSurface, size: 22),
        ],
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STEP 4 OF 6',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.primaryContainer, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                    )),
                  const SizedBox(height: 4),
                  Text('Availability',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurface, fontSize: 28,
                      fontWeight: FontWeight.w800,
                    )),
                ],
              ),
            ),
            Text('66%',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.primaryContainer, fontSize: 24,
                fontWeight: FontWeight.w300,
              )),
          ],
        ),
        const SizedBox(height: 12),
        Stack(children: [
          Container(height: 3,
            decoration: BoxDecoration(color: const Color(0xFF262A30),
              borderRadius: BorderRadius.circular(99))),
          FractionallySizedBox(widthFactor: 0.66,
            child: Container(height: 3,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 12,
                )],
              ))),
        ]),
      ],
    );
  }

  // ── Active status card ─────────────────────────────────────────────────────

  Widget _buildActiveStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF454932).withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Status',
                      style: GoogleFonts.inter(color: AppColors.onSurface,
                        fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Allow clients to find you now',
                      style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              // iOS-style toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isAvailable = !_isAvailable);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 56,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: _isAvailable
                        ? AppColors.primaryContainer
                        : const Color(0xFF444956),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: _isAvailable
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isAvailable
                            ? const Color(0xFF181E00)
                            : Colors.white.withValues(alpha: 0.6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAvailable
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                  boxShadow: _isAvailable ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                      blurRadius: 6,
                    )
                  ] : [],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isAvailable ? 'SYSTEM ONLINE' : 'SYSTEM OFFLINE',
                style: GoogleFonts.spaceGrotesk(
                  color: _isAvailable
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Weekly schedule ────────────────────────────────────────────────────────

  Widget _buildWeeklySchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WEEKLY SCHEDULE',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 2,
          )),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day = _days[i];
            final label = _dayLabels[i];
            final selected = _selectedDays.contains(day);
            return GestureDetector(
              onTap: () => _toggleDay(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryContainer
                        : const Color(0xFF454932).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: selected ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      blurRadius: 10,
                    )
                  ] : [],
                ),
                child: Center(
                  child: Text(label,
                    style: GoogleFonts.spaceGrotesk(
                      color: selected
                          ? const Color(0xFF181E00)
                          : AppColors.onSurfaceVariant,
                      fontSize: 14, fontWeight: FontWeight.w700,
                    )),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Time range ─────────────────────────────────────────────────────────────

  Widget _buildTimeRange() {
    return Row(
      children: [
        Expanded(child: _timePicker(label: 'START TIME', time: _startTime, isStart: true)),
        const SizedBox(width: 16),
        Expanded(child: _timePicker(label: 'END TIME', time: _endTime, isStart: false)),
      ],
    );
  }

  Widget _timePicker({
    required String label,
    required TimeOfDay time,
    required bool isStart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1.5,
          )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickTime(isStart: isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2025),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF454932), width: 2),
              ),
            ),
            child: Row(
              children: [
                Text(_formatTime(time),
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurface, fontSize: 18,
                    fontWeight: FontWeight.w600,
                  )),
                const Spacer(),
                Icon(Icons.access_time,
                  color: AppColors.onSurfaceVariant, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Service radius ─────────────────────────────────────────────────────────

  Widget _buildServiceRadius() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SERVICE RADIUS',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 2,
          )),
        const SizedBox(height: 14),

        // Map placeholder + detect button
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFF262A30),
            child: Stack(
              children: [
                if (_currentLocation != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 12.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.domfix',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _currentLocation!,
                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                            borderColor: AppColors.primaryContainer,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: _radiusMiles * 1609.34,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFD9FF00),
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _MapGridPainter(),
                  ),
                
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.background.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                // Detect button
                if (_currentLocation == null)
                  Center(
                    child: GestureDetector(
                      onTap: _detectingLocation ? null : _detectLocation,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                            )
                          ],
                        ),
                        child: _detectingLocation
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF101419)),
                                ))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.my_location,
                                      color: Color(0xFF101419), size: 18),
                                  const SizedBox(width: 8),
                                  Text('Detect Current Location',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF101419),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    )),
                                ],
                              ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _detectingLocation ? null : _detectLocation,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2025),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: _detectingLocation
                           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD9FF00))))
                           : const Icon(Icons.my_location, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.share_location,
                color: AppColors.onSurfaceVariant, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_detectedLocation,
                style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant, fontSize: 12)),
            ),
            GestureDetector(
              onTap: () {
                // Could open radius picker
              },
              child: Text('CHANGE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5,
                )),
            ),
          ],
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(top: BorderSide(
          color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.6), size: 22),
                const SizedBox(height: 2),
                Text('BACK',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5,
                  )),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _handleNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  blurRadius: 20, offset: const Offset(0, 6),
                )],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: const Color(0xFF2B3400), size: 20),
                  const SizedBox(height: 2),
                  Text('NEXT',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF2B3400),
                      fontWeight: FontWeight.w800,
                      fontSize: 11, letterSpacing: 2,
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative map grid painter ───────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD9FF00).withValues(alpha: 0.06)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Center circle
    final circlePaint = Paint()
      ..color = const Color(0xFFD9FF00).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 50, circlePaint);
    canvas.drawCircle(center, 80, circlePaint
      ..color = const Color(0xFFD9FF00).withValues(alpha: 0.07));

    // Center dot
    canvas.drawCircle(
      center, 5,
      Paint()..color = const Color(0xFFD9FF00).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
