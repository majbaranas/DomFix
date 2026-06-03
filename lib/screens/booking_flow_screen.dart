import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/booking_service.dart';
import '../services/chat_service.dart';
import '../services/firebase_storage_service.dart';
import '../theme/app_colors.dart';
import 'booking_confirmation_screen.dart';

class BookingFlowScreen extends StatefulWidget {
  final String technicianId;
  final String technicianName;
  final String? technicianPhotoUrl;
  final String technicianRole;
  final List<String> availableServices;
  final double technicianRating;
  final int experienceYears;
  final String replyTime;

  const BookingFlowScreen({
    super.key,
    required this.technicianId,
    required this.technicianName,
    required this.technicianRole,
    required this.availableServices,
    required this.technicianRating,
    required this.experienceYears,
    required this.replyTime,
    this.technicianPhotoUrl,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  static const int _stepCount = 5;
  static const int _descriptionLimit = 500;

  final _bookingService = BookingService.instance;
  final _storageService = FirebaseStorageService();
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();

  late final List<String> _serviceOptions;
  final List<File> _selectedImages = [];

  DateTime _selectedDate = DateTime.now();
  _AvailabilitySlot? _selectedSlot;
  String? _selectedService;
  String _urgency = 'Normal';
  List<_AvailabilitySlot> _slots = [];
  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isRefreshingSlots = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _serviceOptions = _buildServiceOptions();
    _selectedService = _serviceOptions.isNotEmpty ? _serviceOptions.first : null;
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _descriptionController.addListener(_handleDescriptionChange);
    _refreshSlots();
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_handleDescriptionChange)
      ..dispose();
    super.dispose();
  }

  List<String> _buildServiceOptions() {
    final seen = <String>{};
    final services = <String>[];

    for (final value in widget.availableServices) {
      final normalized = value.trim();
      if (normalized.isEmpty || seen.contains(normalized.toLowerCase())) {
        continue;
      }
      seen.add(normalized.toLowerCase());
      services.add(normalized);
    }

    if (services.isEmpty) {
      services.addAll(const [
        'Electrical Repair',
        'Smart Home Installation',
        'IoT Setup',
        'Wiring',
        'Maintenance',
        'Diagnostics',
      ]);
    }

    return services;
  }

  void _handleDescriptionChange() {
    if (!mounted) return;
    setState(() {
      if (_descriptionController.text.trim().isNotEmpty) {
        _validationMessage = null;
      }
    });
  }

  Future<void> _refreshSlots() async {
    setState(() => _isRefreshingSlots = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final slots = _buildSlotsForDate(_selectedDate);

    if (!mounted) return;
    setState(() {
      _slots = slots;
      if (_selectedSlot != null &&
          !_slots.any((slot) => slot.label == _selectedSlot!.label)) {
        _selectedSlot = null;
      }
      _isRefreshingSlots = false;
    });
  }

  List<_AvailabilitySlot> _buildSlotsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final seed = widget.technicianId.hashCode ^
        (normalizedDate.year * 100000 +
            normalizedDate.month * 1000 +
            normalizedDate.day * 31);
    final random = Random(seed);
    final slots = <_AvailabilitySlot>[];

    for (var hour = 8; hour <= 18; hour++) {
      final time = TimeOfDay(hour: hour, minute: 0);
      final slotDate = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        hour,
        0,
      );
      final liveAvailability = random.nextDouble() > 0.35;
      final isPast = slotDate.isBefore(now.add(const Duration(minutes: 45)));
      final available = liveAvailability && !isPast;
      slots.add(
        _AvailabilitySlot(
          time: time,
          label: _formatTimeOfDay(time),
          available: available,
          reason: isPast ? 'Past' : (liveAvailability ? 'Open' : 'Booked'),
        ),
      );
    }

    return slots;
  }

  Future<void> _pickDate() async {
    final initialDate = _selectedDate;
    final firstDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.neonAccent,
                  onPrimary: AppColors.onPrimary,
                  surface: AppColors.surface,
                  onSurface: AppColors.onSurface,
                ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surface,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedSlot = null;
    });
    await _refreshSlots();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 4) {
      _showSnack('You can attach up to 4 photos.');
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 78,
      );
      if (images.isEmpty) return;

      setState(() {
        for (final image in images) {
          if (_selectedImages.length >= 4) break;
          _selectedImages.add(File(image.path));
        }
      });
    } catch (e) {
      _showSnack('Could not pick images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedService != null;
      case 1:
        return _selectedSlot != null;
      case 2:
        return _descriptionController.text.trim().isNotEmpty &&
            _descriptionController.text.trim().length <= _descriptionLimit;
      case 3:
      case 4:
        return true;
      default:
        return false;
    }
  }

  String get _continueLabel {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
        return 'Continue';
      case 3:
        return 'Review booking';
      case 4:
        return 'Confirm booking';
      default:
        return 'Continue';
    }
  }

  _BookingEstimate _buildEstimate() {
    final service = _selectedService ?? _serviceOptions.first;
    final serviceLower = service.toLowerCase();
    final baseDuration = serviceLower.contains('diagnostic')
        ? 45
        : serviceLower.contains('installation')
            ? 120
            : serviceLower.contains('wiring')
                ? 150
                : serviceLower.contains('maintenance')
                    ? 75
                    : 90;

    final urgencyMultiplier = switch (_urgency) {
      'Urgent' => 1.18,
      'Emergency' => 1.42,
      _ => 1.0,
    };

    final experienceModifier = widget.experienceYears >= 5 ? 0.92 : 1.0;
    final ratingModifier = widget.technicianRating >= 4.8 ? 0.95 : 1.0;
    final technicianFee =
        (42 + baseDuration * 0.58) * urgencyMultiplier * experienceModifier;
    final platformFee = (technicianFee * 0.12).clamp(6.0, 18.0);
    final totalBase = technicianFee + platformFee;
    final minPrice = totalBase * 0.9 * ratingModifier;
    final maxPrice = totalBase * 1.18 * urgencyMultiplier;

    return _BookingEstimate(
      durationMinutes: baseDuration,
      priceMin: minPrice,
      priceMax: maxPrice,
      technicianFee: technicianFee,
      platformFee: platformFee,
    );
  }

  String _serviceIdFor(String serviceName) {
    return serviceName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> _goNext() async {
    if (!_canContinue || _isSubmitting) {
      if (_currentStep == 2 &&
          _descriptionController.text.trim().isEmpty) {
        setState(() {
          _validationMessage = 'Please describe the issue before continuing.';
        });
      }
      return;
    }

    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep += 1);
      return;
    }

    await _confirmBooking();
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() => _currentStep -= 1);
  }

  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please sign in to complete the booking.');
      return;
    }

    if (_selectedService == null || _selectedSlot == null) {
      _showSnack('Please finish the booking details.');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showSnack('Add a short description of the problem.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bookingId = _bookingService.newBookingId();
      final uploadedImages = <String>[];
      for (final image in _selectedImages) {
        final url = await _storageService.uploadBookingImage(
          bookingId: bookingId,
          imageFile: image,
          onProgress: (_) {},
        );
        uploadedImages.add(url);
      }

      final estimate = _buildEstimate();
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedSlot!.time.hour,
        _selectedSlot!.time.minute,
      );

      final booking = await BookingService.instance.createBooking(
        bookingId: bookingId,
        clientId: user.uid,
        technicianId: widget.technicianId,
        technicianName: widget.technicianName,
        serviceId: _serviceIdFor(_selectedService!),
        serviceName: _selectedService!,
        scheduledAt: scheduledAt,
        scheduledTimeLabel: _selectedSlot!.label,
        description: description,
        urgency: _urgency,
        imageUrls: uploadedImages,
        estimatedDurationMinutes: estimate.durationMinutes,
        estimatedPriceMin: estimate.priceMin,
        estimatedPriceMax: estimate.priceMax,
        technicianFee: estimate.technicianFee,
        platformFee: estimate.platformFee,
      );

      try {
        await ChatService().sendMessage(
          receiverId: widget.technicianId,
          text:
              'Booking confirmed for ${_selectedService!} on ${_formatDate(_selectedDate)} at ${_selectedSlot!.label}.',
        );
      } catch (e) {
        debugPrint('[BookingFlow] Unable to send booking summary message: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return BookingConfirmationScreen(
              booking: booking,
              technicianName: widget.technicianName,
              technicianPhotoUrl: widget.technicianPhotoUrl,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } catch (e) {
      _showSnack('Booking failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${date.month}/${date.day}/${date.year}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  IconData _serviceIcon(String service) {
    final value = service.toLowerCase();
    if (value.contains('electrical') || value.contains('wiring')) {
      return Icons.bolt_rounded;
    }
    if (value.contains('smart') || value.contains('home')) {
      return Icons.home_rounded;
    }
    if (value.contains('iot') || value.contains('network')) {
      return Icons.router_rounded;
    }
    if (value.contains('maintenance')) {
      return Icons.handyman_rounded;
    }
    if (value.contains('repair')) {
      return Icons.build_circle_rounded;
    }
    return Icons.settings_rounded;
  }

  Color _serviceTint(String service) {
    final value = service.toLowerCase();
    if (value.contains('emergency')) return AppColors.emergency;
    if (value.contains('smart')) return const Color(0xFF79CFFF);
    if (value.contains('iot')) return const Color(0xFF9E9BFF);
    if (value.contains('maintenance')) return const Color(0xFFF5B15B);
    return AppColors.neonAccent;
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _buildEstimate();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            LinearProgressIndicator(
              value: (_currentStep + 1) / _stepCount,
              minHeight: 2,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.neonAccent),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey(_currentStep),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: _buildStepContent(estimate),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final selectedSlot = _selectedSlot?.label ?? 'Select a time';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.onSurface,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book ${widget.technicianName}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${_currentStep + 1} of $_stepCount · $selectedSlot',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.replyTime,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(_BookingEstimate estimate) {
    switch (_currentStep) {
      case 0:
        return _buildServiceStep();
      case 1:
        return _buildScheduleStep();
      case 2:
        return _buildProblemStep();
      case 3:
        return _buildEstimateStep(estimate);
      case 4:
        return _buildReviewStep(estimate);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceStep() {
    return Column(
      key: const ValueKey('service-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Select service',
          'Pick the type of support you need. The technician specialties are pulled from their profile and adapted to the services they actually handle.',
        ),
        const SizedBox(height: 20),
        GridView.builder(
          itemCount: _serviceOptions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final service = _serviceOptions[index];
            final selected = _selectedService == service;
            final tint = _serviceTint(service);
            return GestureDetector(
              onTap: () => setState(() => _selectedService = service),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? tint.withValues(alpha: 0.14)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? tint : AppColors.divider,
                    width: selected ? 1.4 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: tint.withValues(alpha: 0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _serviceIcon(service),
                            color: tint,
                            size: 22,
                          ),
                        ),
                        AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.neonAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected ? 'Selected' : 'Tap to choose',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleStep() {
    final availableCount =
        _slots.where((slot) => slot.available).length;

    return Column(
      key: const ValueKey('schedule-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Choose date and time',
          'Availability is simulated in real time so the experience feels live and adaptive. Past times are always locked out.',
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.neonAccent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled date',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(_selectedDate),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$availableCount slots available',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _isRefreshingSlots ? 'Refreshing...' : 'Live',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Available time slots',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        if (_isRefreshingSlots)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.neonAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_slots.where((slot) => slot.available).isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No open slots for this date',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try another day to see more availability.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _slots.map((slot) {
              final selected = _selectedSlot?.label == slot.label;
              final disabled = !slot.available;
              return GestureDetector(
                onTap: disabled ? null : () => setState(() => _selectedSlot = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.neonAccent
                        : disabled
                            ? AppColors.surfaceContainerHigh.withValues(alpha: 0.45)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.neonAccent
                          : disabled
                              ? AppColors.divider.withValues(alpha: 0.4)
                              : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.onPrimary
                              : disabled
                                  ? AppColors.onSurfaceVariant.withValues(alpha: 0.35)
                                  : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot.reason,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: selected
                              ? AppColors.onPrimary.withValues(alpha: 0.8)
                              : disabled
                                  ? AppColors.onSurfaceVariant.withValues(alpha: 0.25)
                                  : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildProblemStep() {
    return Column(
      key: const ValueKey('problem-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Describe the issue',
          'Explain what is happening, add photos if it helps, and choose the urgency level so the estimate feels realistic.',
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 6,
            maxLength: _descriptionLimit,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurface,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
                  'Example: The kitchen socket keeps tripping the breaker whenever I plug in the kettle.',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                height: 1.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _validationMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        Text(
          'Urgency',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: ['Normal', 'Urgent', 'Emergency'].map((urgency) {
            final selected = _urgency == urgency;
            final color = switch (urgency) {
              'Urgent' => const Color(0xFFFFB84D),
              'Emergency' => AppColors.emergency,
              _ => AppColors.neonAccent,
            };
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _urgency = urgency),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? color : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : AppColors.divider,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        urgency,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Optional images',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              '${_selectedImages.length}/4',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.neonAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImages.length + 1,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 98,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.neonAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.neonAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add photo',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final file = _selectedImages[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(
                      file,
                      width: 98,
                      height: 98,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: 98,
                        height: 98,
                        color: AppColors.surfaceContainerHigh,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateStep(_BookingEstimate estimate) {
    return Column(
      key: const ValueKey('estimate-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Price estimate',
          'Transparent pricing is shown before confirmation so the booking feels clear and trustworthy.',
        ),
        const SizedBox(height: 20),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.neonAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${estimate.priceMin.toStringAsFixed(0)} - ${estimate.priceMax.toStringAsFixed(0)} MAD',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Premium estimate for your selected service',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _EstimateRow(
                label: 'Estimated duration',
                value: '${estimate.durationMinutes} min',
              ),
              const SizedBox(height: 12),
              _EstimateRow(
                label: 'Technician fee',
                value: '${estimate.technicianFee.toStringAsFixed(0)} MAD',
              ),
              const SizedBox(height: 12),
              _EstimateRow(
                label: 'Platform fee',
                value: '${estimate.platformFee.toStringAsFixed(0)} MAD',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What you selected',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _SummaryLine(
                icon: Icons.build_circle_outlined,
                label: _selectedService ?? 'Service',
              ),
              const SizedBox(height: 8),
              _SummaryLine(
                icon: Icons.schedule_rounded,
                label:
                    '${_formatDate(_selectedDate)} · ${_selectedSlot?.label ?? 'Time'}',
              ),
              const SizedBox(height: 8),
              _SummaryLine(
                icon: Icons.priority_high_rounded,
                label: _urgency,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(_BookingEstimate estimate) {
    return Column(
      key: const ValueKey('review-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Review and confirm',
          'This is the final check before the booking is saved to Firestore and the full chat experience is unlocked.',
        ),
        const SizedBox(height: 20),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: widget.technicianPhotoUrl != null
                          ? Image.network(
                              widget.technicianPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _TechnicianAvatar(
                                initials: widget.technicianName,
                              ),
                            )
                          : _TechnicianAvatar(initials: widget.technicianName),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.technicianName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.technicianRole,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.neonAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.technicianRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ReviewItem(
                label: 'Service',
                value: _selectedService ?? '',
              ),
              const SizedBox(height: 12),
              _ReviewItem(
                label: 'Date and time',
                value:
                    '${_formatDate(_selectedDate)} · ${_selectedSlot?.label ?? ''}',
              ),
              const SizedBox(height: 12),
              _ReviewItem(
                label: 'Urgency',
                value: _urgency,
              ),
              const SizedBox(height: 12),
              _ReviewItem(
                label: 'Description',
                value: _descriptionController.text.trim(),
              ),
              const SizedBox(height: 12),
              _ReviewItem(
                label: 'Estimated range',
                value:
                    '${estimate.priceMin.toStringAsFixed(0)} - ${estimate.priceMax.toStringAsFixed(0)} MAD',
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReviewItem(
                  label: 'Photos',
                  value: '${_selectedImages.length} attached',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == _stepCount - 1;
    return Container(
      padding:
          EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isSubmitting ? null : _goBack,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Text(
                    _currentStep == 0 ? 'Cancel' : 'Back',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _isSubmitting ? null : _goNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _canContinue && !_isSubmitting
                      ? AppColors.neonAccent
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _canContinue && !_isSubmitting
                      ? [
                          BoxShadow(
                            color: AppColors.neonAccent.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const [],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          isLastStep ? 'Confirm booking' : _continueLabel,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _canContinue
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant.withValues(alpha: 0.45),
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

class _AvailabilitySlot {
  final TimeOfDay time;
  final String label;
  final bool available;
  final String reason;

  const _AvailabilitySlot({
    required this.time,
    required this.label,
    required this.available,
    required this.reason,
  });
}

class _BookingEstimate {
  final int durationMinutes;
  final double priceMin;
  final double priceMax;
  final double technicianFee;
  final double platformFee;

  const _BookingEstimate({
    required this.durationMinutes,
    required this.priceMin,
    required this.priceMax,
    required this.technicianFee,
    required this.platformFee,
  });
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final String label;
  final String value;

  const _EstimateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.neonAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _TechnicianAvatar extends StatelessWidget {
  final String initials;

  const _TechnicianAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    final initial = initials.trim().isNotEmpty
        ? initials.trim()[0].toUpperCase()
        : '?';
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.neonAccent,
          ),
        ),
      ),
    );
  }
}
