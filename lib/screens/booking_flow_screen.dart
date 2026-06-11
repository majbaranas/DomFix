import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/booking_service.dart';
import '../services/firebase_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/live_status_badge.dart';
import 'booking_confirmation_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BookingFlowScreen — 8-Step Marketplace Booking Experience
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

class _BookingFlowScreenState extends State<BookingFlowScreen>
    with TickerProviderStateMixin {
  // ─── Constants ──────────────────────────────────────────
  static const int _totalSteps = 8;
  static const int _descriptionMaxLength = 500;
  static const int _descriptionMinLength = 10;
  static const int _descriptionMinWords = 2;
  static const int _maxImages = 4;

  static const List<String> _stepLabels = [
    'Service',
    'Schedule',
    'Describe',
    'Photos',
    'Priority',
    'Estimate',
    'Review',
    'Confirm',
  ];

  static const List<IconData> _stepIcons = [
    Icons.build_circle_rounded,
    Icons.calendar_month_rounded,
    Icons.description_rounded,
    Icons.photo_camera_rounded,
    Icons.priority_high_rounded,
    Icons.payments_rounded,
    Icons.checklist_rounded,
    Icons.verified_rounded,
  ];

  // ─── Services ───────────────────────────────────────────
  final _bookingService = BookingService.instance;
  final _storageService = FirebaseStorageService();
  final _imagePicker = ImagePicker();

  // ─── Controllers ────────────────────────────────────────
  final _descriptionController = TextEditingController();
  late final PageController _pageController;
  late final AnimationController _progressAnimController;
  late final Animation<double> _progressAnim;

  // ─── State ──────────────────────────────────────────────
  late final List<String> _serviceOptions;
  final List<File> _selectedImages = [];
  final List<double> _uploadProgress = [];

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _selectedService;
  String _urgency = 'Medium';
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _descriptionError;

  // Real-time booked slots
  List<TimeOfDay> _bookedSlots = [];
  bool _isLoadingSlots = true;

  @override
  void initState() {
    super.initState();
    _serviceOptions = _buildServiceOptions();
    _selectedService =
        _serviceOptions.isNotEmpty ? _serviceOptions.first : null;
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _pageController = PageController();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeOutCubic,
    );
    _descriptionController.addListener(_onDescriptionChanged);
    _loadBookedSlots();
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_onDescriptionChanged)
      ..dispose();
    _pageController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  // ─── Service Options ────────────────────────────────────

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

  // ─── Availability Loading ───────────────────────────────

  Future<void> _loadBookedSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final slots = await _bookingService.getBookedSlotsForDate(
        technicianId: widget.technicianId,
        date: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _bookedSlots = slots;
        _isLoadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookedSlots = [];
        _isLoadingSlots = false;
      });
    }
  }

  bool _isSlotBooked(TimeOfDay time) {
    return _bookedSlots.any(
      (booked) => booked.hour == time.hour && booked.minute == time.minute,
    );
  }

  bool _isSlotPast(TimeOfDay time) {
    final now = DateTime.now();
    final slotDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    return slotDate.isBefore(now.add(const Duration(minutes: 45)));
  }

  // ─── Validation ─────────────────────────────────────────

  void _onDescriptionChanged() {
    if (!mounted) return;
    final text = _descriptionController.text.trim();
    setState(() {
      if (text.isNotEmpty) _descriptionError = _validateDescription(text);
    });
  }

  String? _validateDescription(String text) {
    if (text.isEmpty) return 'Please describe the issue.';
    if (text.length < _descriptionMinLength) {
      return 'Description must be at least $_descriptionMinLength characters.';
    }
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < _descriptionMinWords) {
      return 'Please use at least $_descriptionMinWords words to describe the issue.';
    }
    if (text.length > _descriptionMaxLength) {
      return 'Description cannot exceed $_descriptionMaxLength characters.';
    }
    return null;
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedService != null;
      case 1:
        return _selectedTime != null;
      case 2:
        final text = _descriptionController.text.trim();
        return text.isNotEmpty && _validateDescription(text) == null;
      case 3: // Photos — optional
      case 4: // Priority — always has default
      case 5: // Estimate — read-only
      case 6: // Review — read-only
      case 7: // Confirm
        return true;
      default:
        return false;
    }
  }

  String get _continueLabel {
    switch (_currentStep) {
      case 5:
        return 'Review booking';
      case 6:
        return 'Confirm booking';
      case 7:
        return 'Done';
      default:
        return 'Continue';
    }
  }

  // ─── Estimation Engine ──────────────────────────────────

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
      'High' => 1.18,
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

  // ─── Image Picking ──────────────────────────────────────

  Future<void> _showImageSourcePicker() async {
    if (_selectedImages.length >= _maxImages) {
      _showSnack('You can attach up to $_maxImages photos.');
      return;
    }

    HapticFeedback.lightImpact();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageSourceSheet(
        maxRemaining: _maxImages - _selectedImages.length,
      ),
    );
    if (source == null) return;

    try {
      if (source == ImageSource.camera) {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 78,
        );
        if (image != null && mounted) {
          setState(() => _selectedImages.add(File(image.path)));
        }
      } else {
        final images = await _imagePicker.pickMultiImage(imageQuality: 78);
        if (images.isNotEmpty && mounted) {
          setState(() {
            for (final image in images) {
              if (_selectedImages.length >= _maxImages) break;
              _selectedImages.add(File(image.path));
            }
          });
        }
      }
    } catch (e) {
      _showSnack('Could not pick images: $e');
    }
  }

  void _removeImage(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedImages.removeAt(index));
  }

  // ─── Navigation ─────────────────────────────────────────

  void _goNext() {
    if (!_canContinue || _isSubmitting) {
      if (_currentStep == 2) {
        final text = _descriptionController.text.trim();
        setState(() {
          _descriptionError = text.isEmpty
              ? 'Please describe the issue before continuing.'
              : _validateDescription(text);
        });
      }
      return;
    }

    HapticFeedback.selectionClick();

    if (_currentStep == 6) {
      _confirmBooking();
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _currentStep -= 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpToStep(int step) {
    if (step >= _currentStep) return;
    HapticFeedback.selectionClick();
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // ─── Booking Submission ─────────────────────────────────

  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please sign in to complete the booking.');
      return;
    }

    if (_selectedService == null || _selectedTime == null) {
      _showSnack('Please finish the booking details.');
      return;
    }

    final description = _descriptionController.text.trim();
    if (_validateDescription(description) != null) {
      _showSnack('Please provide a valid description.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bookingId = _bookingService.newBookingId();

      // Upload images with progress
      final uploadedImages = <String>[];
      for (var i = 0; i < _selectedImages.length; i++) {
        final url = await _storageService.uploadBookingImage(
          bookingId: bookingId,
          imageFile: _selectedImages[i],
          onProgress: (progress) {
            // Progress tracking per image
          },
        );
        uploadedImages.add(url);
      }

      final estimate = _buildEstimate();
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final booking = await BookingService.instance.createBooking(
        bookingId: bookingId,
        clientId: user.uid,
        technicianId: widget.technicianId,
        technicianName: widget.technicianName,
        serviceId: _serviceIdFor(_selectedService!),
        serviceName: _selectedService!,
        scheduledAt: scheduledAt,
        scheduledTimeLabel: _formatTimeOfDay(_selectedTime!),
        description: description,
        urgency: _urgency,
        imageUrls: uploadedImages,
        estimatedDurationMinutes: estimate.durationMinutes,
        estimatedPriceMin: estimate.priceMin,
        estimatedPriceMax: estimate.priceMax,
        technicianFee: estimate.technicianFee,
        platformFee: estimate.platformFee,
      );

      if (!mounted) return;

      // Navigate to step 8 (confirmation) inline
      setState(() {
        _currentStep = 7;
        _isSubmitting = false;
      });
      _pageController.animateToPage(
        7,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );

      // Store booking for confirmation display
      _confirmedBooking = booking;
    } catch (e) {
      _showSnack('$e');
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ignore: unused_field — set during confirmation flow
  dynamic _confirmedBooking;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────

  String _serviceIdFor(String serviceName) {
    return serviceName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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
    if (value.contains('maintenance')) return Icons.handyman_rounded;
    if (value.contains('repair')) return Icons.build_circle_rounded;
    if (value.contains('diagnostic')) return Icons.troubleshoot_rounded;
    return Icons.settings_rounded;
  }

  Color _serviceTint(String service) {
    final value = service.toLowerCase();
    if (value.contains('emergency')) return AppColors.emergency;
    if (value.contains('smart')) return const Color(0xFF79CFFF);
    if (value.contains('iot')) return const Color(0xFF9E9BFF);
    if (value.contains('maintenance')) return const Color(0xFFF5B15B);
    if (value.contains('diagnostic')) return const Color(0xFF4ECDC4);
    return AppColors.neonAccent;
  }

  String _estimatedDurationForService(String service) {
    final value = service.toLowerCase();
    if (value.contains('diagnostic')) return '~45 min';
    if (value.contains('installation')) return '~2 hrs';
    if (value.contains('wiring')) return '~2.5 hrs';
    if (value.contains('maintenance')) return '~1.5 hrs';
    return '~1.5 hrs';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Service(),
                  _buildStep2Schedule(),
                  _buildStep3Description(),
                  _buildStep4Photos(),
                  _buildStep5Priority(),
                  _buildStep6Estimate(),
                  _buildStep7Review(),
                  _buildStep8Confirmation(),
                ],
              ),
            ),
            if (_currentStep < 7) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps · ${_stepLabels[_currentStep]}',
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

  // ─── Step Indicator ─────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _totalSteps,
        itemBuilder: (context, index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          final color = isActive
              ? AppColors.neonAccent
              : isCompleted
                  ? AppColors.neonAccent.withValues(alpha: 0.5)
                  : AppColors.surfaceContainerHigh;

          return GestureDetector(
            onTap: isCompleted ? () => _jumpToStep(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 16 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.neonAccent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompleted)
                    Icon(Icons.check_rounded, size: 16, color: color)
                  else
                    Icon(_stepIcons[index], size: 16, color: color),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      _stepLabels[index],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Bottom Action Bar ──────────────────────────────────

  Widget _buildBottomBar() {
    final isReviewStep = _currentStep == 6;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 14, 20, MediaQuery.of(context).padding.bottom + 14,
      ),
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
                      ? isReviewStep
                          ? AppColors.success
                          : AppColors.neonAccent
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _canContinue && !_isSubmitting
                      ? [
                          BoxShadow(
                            color: (isReviewStep
                                    ? AppColors.success
                                    : AppColors.neonAccent)
                                .withValues(alpha: 0.18),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _continueLabel,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _canContinue
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                            if (isReviewStep && _canContinue) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.onPrimary,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 1 — SELECT SERVICE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep1Service() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Select service',
            subtitle:
                'Pick the type of support you need from ${widget.technicianName}\'s specialties.',
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
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final service = _serviceOptions[index];
              final selected = _selectedService == service;
              final tint = _serviceTint(service);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedService = service);
                },
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
                              decoration: BoxDecoration(
                                color: tint,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _estimatedDurationForService(service),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 2 — DATE & TIME SELECTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep2Schedule() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      30,
      (i) => today.add(Duration(days: i)),
    );

    // Build time slots for the working day
    final timeSlots = <TimeOfDay>[];
    for (var h = 8; h <= 18; h++) {
      timeSlots.add(TimeOfDay(hour: h, minute: 0));
    }

    final availableCount = timeSlots.where((t) {
      return !_isSlotBooked(t) && !_isSlotPast(t);
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Choose date & time',
            subtitle:
                'Availability updates in real-time. Unavailable slots are greyed out.',
          ),
          const SizedBox(height: 16),

          // ─── Horizontal Date Picker ─────────────────────
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = date.day == today.day &&
                    date.month == today.month &&
                    date.year == today.year;

                const days = [
                  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
                ];

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = null;
                    });
                    _loadBookedSlots();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonAccent
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonAccent
                            : isToday
                                ? AppColors.neonAccent.withValues(alpha: 0.3)
                                : AppColors.divider,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          days[date.weekday - 1],
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.onSurface,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.onPrimary
                                  : AppColors.neonAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ─── Availability Badge ─────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: availableCount > 0
                        ? AppColors.success
                        : AppColors.emergency,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isLoadingSlots
                      ? 'Checking availability...'
                      : '$availableCount slots available',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(_selectedDate),
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

          // ─── Time Slots Grid ────────────────────────────
          Text(
            'Available time slots',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoadingSlots)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.neonAccent,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (availableCount == 0)
            _buildNoSlotsCard()
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: timeSlots.map((time) {
                final booked = _isSlotBooked(time);
                final past = _isSlotPast(time);
                final disabled = booked || past;
                final selected = _selectedTime != null &&
                    _selectedTime!.hour == time.hour &&
                    _selectedTime!.minute == time.minute;

                return GestureDetector(
                  onTap: disabled
                      ? () => _showUnavailableDialog(time, booked)
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTime = time);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.neonAccent
                          : disabled
                              ? AppColors.surfaceContainerHigh
                                  .withValues(alpha: 0.45)
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
                          _formatTimeOfDay(time),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.onPrimary
                                : disabled
                                    ? AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.35)
                                    : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          disabled
                              ? (booked ? 'Booked' : 'Past')
                              : 'Available',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: selected
                                ? AppColors.onPrimary.withValues(alpha: 0.8)
                                : disabled
                                    ? AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.25)
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoSlotsCard() {
    return Container(
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
    );
  }

  void _showUnavailableDialog(TimeOfDay time, bool isBooked) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: AppColors.emergency,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Time Slot Unavailable',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isBooked
                    ? 'This time slot is already reserved. Please choose another available time.'
                    : 'This time has already passed. Please select a future time slot.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Choose another time',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 3 — PROBLEM DESCRIPTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep3Description() {
    final text = _descriptionController.text.trim();
    final charCount = text.length;
    final wordCount =
        text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasError = _descriptionError != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Describe the issue',
            subtitle:
                'Provide a clear description so the technician can prepare for the job.',
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasError ? AppColors.emergency : AppColors.divider,
              ),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: 6,
              maxLength: _descriptionMaxLength,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'Example: Kitchen lights not working, the circuit breaker trips every time I turn them on.',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                  height: 1.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasError)
                Expanded(
                  child: Text(
                    _descriptionError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.emergency,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    '$wordCount ${wordCount == 1 ? 'word' : 'words'} · min $_descriptionMinWords words',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: wordCount >= _descriptionMinWords
                          ? AppColors.success
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                '$charCount / $_descriptionMaxLength',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: charCount > _descriptionMaxLength
                      ? AppColors.emergency
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 4 — ATTACH PHOTOS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep4Photos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Attach photos',
            subtitle:
                'Add photos of the issue to help the technician come prepared. This step is optional.',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Photos',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                '${_selectedImages.length}/$_maxImages',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedImages.isEmpty)
            GestureDetector(
              onTap: _showImageSourcePicker,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.divider,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.neonAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add photos',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take a photo or choose from gallery',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length +
                        (_selectedImages.length < _maxImages ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      // Add button at the end
                      if (index == _selectedImages.length) {
                        return GestureDetector(
                          onTap: _showImageSourcePicker,
                          child: Container(
                            width: 130,
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
                                    color: AppColors.neonAccent
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.neonAccent,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add more',
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
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 130,
                                height: 130,
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
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Image number badge
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
            ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 5 — PRIORITY SELECTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep5Priority() {
    const priorities = [
      _PriorityOption(
        label: 'Low',
        icon: Icons.arrow_downward_rounded,
        color: AppColors.lowPriority,
        description: 'Non-urgent issue. Can be scheduled at convenience.',
      ),
      _PriorityOption(
        label: 'Medium',
        icon: Icons.remove_rounded,
        color: AppColors.mediumPriority,
        description: 'Standard priority. Schedule within a few days.',
      ),
      _PriorityOption(
        label: 'High',
        icon: Icons.arrow_upward_rounded,
        color: AppColors.highPriority,
        description: 'Urgent issue affecting daily activities.',
      ),
      _PriorityOption(
        label: 'Emergency',
        icon: Icons.warning_amber_rounded,
        color: AppColors.emergency,
        description: 'Critical situation requiring immediate attention.',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Select priority',
            subtitle:
                'How urgent is this issue? This helps the technician prioritize your request.',
          ),
          const SizedBox(height: 20),
          ...priorities.map((priority) {
            final selected = _urgency == priority.label;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _urgency = priority.label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? priority.color.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? priority.color : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: priority.color.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : const [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: priority.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          priority.icon,
                          color: priority.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              priority.label,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              priority.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: priority.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 6 — INTELLIGENT ESTIMATION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep6Estimate() {
    final estimate = _buildEstimate();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Price estimate',
            subtitle:
                'Transparent pricing is shown before confirmation so the booking feels clear and trustworthy.',
          ),
          const SizedBox(height: 20),

          // ─── Main Price Card ────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassBorder),
            ),
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
                            '${estimate.priceMin.toStringAsFixed(0)} – ${estimate.priceMax.toStringAsFixed(0)} MAD',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Estimated price range',
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
                Container(
                  height: 1,
                  color: AppColors.divider,
                ),
                const SizedBox(height: 16),
                _EstimateRow(
                  icon: Icons.timer_outlined,
                  label: 'Estimated duration',
                  value: '${estimate.durationMinutes} min',
                ),
                const SizedBox(height: 14),
                _EstimateRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Technician fee',
                  value: '${estimate.technicianFee.toStringAsFixed(0)} MAD',
                ),
                const SizedBox(height: 14),
                _EstimateRow(
                  icon: Icons.shield_outlined,
                  label: 'Platform fee',
                  value: '${estimate.platformFee.toStringAsFixed(0)} MAD',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Selection Summary ──────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR SELECTION',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  icon: Icons.build_circle_outlined,
                  label: _selectedService ?? 'Service',
                ),
                const SizedBox(height: 8),
                _SummaryLine(
                  icon: Icons.schedule_rounded,
                  label:
                      '${_formatDate(_selectedDate)} · ${_selectedTime != null ? _formatTimeOfDay(_selectedTime!) : 'Time'}',
                ),
                const SizedBox(height: 8),
                _SummaryLine(
                  icon: Icons.priority_high_rounded,
                  label: '$_urgency priority',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 7 — BOOKING REVIEW
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep7Review() {
    final estimate = _buildEstimate();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Review & confirm',
            subtitle:
                'This is your final check before sending the booking request.',
          ),
          const SizedBox(height: 20),

          // ─── Technician Card ────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
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
                                errorBuilder: (_, __, ___) =>
                                    _TechnicianAvatar(
                                  initials: widget.technicianName,
                                ),
                              )
                            : _TechnicianAvatar(
                                initials: widget.technicianName,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(widget.technicianId).snapshots(),
                            builder: (context, snapshot) {
                              final status = snapshot.hasData && snapshot.data?.data() != null 
                                  ? (snapshot.data!.data() as Map<String, dynamic>)['liveStatus'] as String? ?? 'offline' 
                                  : 'offline';
                              return Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.technicianName,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  LiveStatusBadge(status: status, size: 8),
                                ],
                              );
                            }
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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

                // Review items with edit buttons
                _ReviewRow(
                  label: 'Service',
                  value: _selectedService ?? '',
                  onEdit: () => _jumpToStep(0),
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Date & time',
                  value:
                      '${_formatDate(_selectedDate)} · ${_selectedTime != null ? _formatTimeOfDay(_selectedTime!) : ''}',
                  onEdit: () => _jumpToStep(1),
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Priority',
                  value: _urgency,
                  onEdit: () => _jumpToStep(4),
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Description',
                  value: _descriptionController.text.trim(),
                  onEdit: () => _jumpToStep(2),
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Estimated range',
                  value:
                      '${estimate.priceMin.toStringAsFixed(0)} – ${estimate.priceMax.toStringAsFixed(0)} MAD',
                ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReviewRow(
                    label: 'Photos',
                    value: '${_selectedImages.length} attached',
                    onEdit: () => _jumpToStep(3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 8 — CONFIRMATION (inline)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildStep8Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // ─── Success Icon ───────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 56,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Booking request sent!',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Full chat is unlocked. You can share photos, send voice notes, and stay in real-time contact with ${widget.technicianName}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // ─── Info Summary Card ──────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLine(
                  icon: Icons.build_circle_outlined,
                  label: _selectedService ?? 'Service',
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.schedule_rounded,
                  label:
                      '${_formatDate(_selectedDate)} · ${_selectedTime != null ? _formatTimeOfDay(_selectedTime!) : ''}',
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.priority_high_rounded,
                  label: '$_urgency priority',
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.info_outline_rounded,
                  label: 'Status: Pending review',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Action Buttons ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_confirmedBooking != null) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => BookingConfirmationScreen(
                            booking: _confirmedBooking,
                            technicianName: widget.technicianName,
                            technicianPhotoUrl: widget.technicianPhotoUrl,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Open chat',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Center(
                      child: Text(
                        'Back to profile',
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
            ],
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SUPPORTING WIDGETS & MODELS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

class _PriorityOption {
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _PriorityOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

// ─── Section Header ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
}

// ─── Estimate Row ─────────────────────────────────────────

class _EstimateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _EstimateRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 10),
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

// ─── Summary Line ─────────────────────────────────────────

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

// ─── Review Row ───────────────────────────────────────────

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  const _ReviewRow({required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  'Edit',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonAccent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: AppColors.onSurface,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Technician Avatar ────────────────────────────────────

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

// ─── Image Source Bottom Sheet ─────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
  final int maxRemaining;
  const _ImageSourceSheet({required this.maxRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Add Photo',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$maxRemaining ${maxRemaining == 1 ? 'photo' : 'photos'} remaining',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.neonAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.neonAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Camera',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.mediumPriority
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: AppColors.mediumPriority,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gallery',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
