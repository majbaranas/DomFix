import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_colors.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import 'chat_screen.dart';

class TechnicianReviewScreen extends StatefulWidget {
  final BookingModel booking;
  final double distanceKm;

  const TechnicianReviewScreen({
    super.key,
    required this.booking,
    required this.distanceKm,
  });

  @override
  State<TechnicianReviewScreen> createState() => _TechnicianReviewScreenState();
}

class _TechnicianReviewScreenState extends State<TechnicianReviewScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentImageIndex = 0;
  bool _isSubmitting = false;

  // Decision state
  int? _selectedDecision; // 0 = remote estimate, 1 = inspection

  // Estimate builder controllers
  final _laborController = TextEditingController();
  final _materialController = TextEditingController();
  final _durationController = TextEditingController();
  final _messageController = TextEditingController();

  late AnimationController _decisionAnimCtrl;
  late Animation<double> _decisionFade;

  @override
  void initState() {
    super.initState();
    _decisionAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _decisionFade = CurvedAnimation(
      parent: _decisionAnimCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _laborController.dispose();
    _materialController.dispose();
    _durationController.dispose();
    _messageController.dispose();
    _decisionAnimCtrl.dispose();
    super.dispose();
  }

  double get _laborCost =>
      double.tryParse(_laborController.text.trim()) ?? 0;
  double get _materialCost =>
      double.tryParse(_materialController.text.trim()) ?? 0;
  double get _totalCost => _laborCost + _materialCost;

  bool get _isEstimateValid =>
      _laborCost > 0 && _durationController.text.trim().isNotEmpty;

  void _selectDecision(int index) {
    if (_selectedDecision == index) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedDecision = index);
    _decisionAnimCtrl.reset();
    _decisionAnimCtrl.forward();
  }

  Future<void> _sendEstimate() async {
    if (!_isEstimateValid || _isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      await BookingService.instance.sendQuote(
        bookingId: widget.booking.id,
        clientId: widget.booking.clientId,
        technicianId: widget.booking.technicianId,
        technicianName: widget.booking.technicianName,
        serviceName: widget.booking.serviceName,
        price: _totalCost,
        duration: _durationController.text.trim(),
        note: _messageController.text.trim(),
        laborCost: _laborCost,
        materialCost: _materialCost,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimate sent successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send estimate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rejectRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reject Request',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to reject this booking request? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reject',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      await BookingService.instance.rejectRequest(
        bookingId: widget.booking.id,
        clientId: widget.booking.clientId,
        technicianId: widget.booking.technicianId,
        technicianName: widget.booking.technicianName,
        serviceName: widget.booking.serviceName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request rejected'),
            backgroundColor: AppColors.onSurfaceVariant,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openInspectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InspectionRequestSheet(
        booking: widget.booking,
        onSubmit: (fee, message, date, time) async {
          Navigator.pop(ctx);
          setState(() => _isSubmitting = true);
          try {
            await BookingService.instance.requestInspection(
              bookingId: widget.booking.id,
              clientId: widget.booking.clientId,
              technicianId: widget.booking.technicianId,
              technicianName: widget.booking.technicianName,
              serviceName: widget.booking.serviceName,
              inspectionFee: fee,
              inspectionMessage: message,
              preferredVisitDate: date,
              preferredVisitTime: time,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Inspection request sent'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error),
              );
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.neonAccent),
                  const SizedBox(height: 16),
                  Text('Processing...',
                      style: GoogleFonts.inter(
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                _buildImageGallery(),
                _buildProblemDetails(),
                _buildDecisionSection(),
                if (_selectedDecision == 0) _buildEstimateBuilder(),
                SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Review Request',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.booking.urgency,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Section 1: Image Gallery ────────────────────────────

  SliverToBoxAdapter _buildImageGallery() {
    final images = widget.booking.imageUrls;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATTACHED PHOTOS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (images.isEmpty)
              _buildEmptyImageState()
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 280,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) =>
                            setState(() => _currentImageIndex = i),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _openFullscreenImage(index),
                            child: images[index].isNotEmpty
                                ? Image.network(
                                    images[index],
                                    width: double.infinity,
                                    height: 280,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: AppColors.shimmerBase,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded /
                                                    (progress.expectedTotalBytes ?? 1)
                                                : null,
                                            color: AppColors.neonAccent,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.surfaceContainerHigh,
                                      height: 280,
                                      child: const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.shimmerBase,
                                    height: 280,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 48,
                                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (images.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == i
                                ? AppColors.neonAccent
                                : AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyImageState() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_search_rounded,
            size: 56,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'No photos provided',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The client did not attach any images',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          imageUrls: widget.booking.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ─── Section 2: Problem Details ──────────────────────────

  SliverToBoxAdapter _buildProblemDetails() {
    final booking = widget.booking;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROBLEM DETAILS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Category
                  _detailRow(
                    Icons.category_rounded,
                    'Service',
                    booking.serviceName,
                  ),
                  _divider(),
                  // Description
                  _detailRow(
                    Icons.description_rounded,
                    'Description',
                    booking.description,
                    isMultiLine: true,
                  ),
                  _divider(),
                  // Date + Time
                  _detailRow(
                    Icons.calendar_today_rounded,
                    'Requested Date',
                    booking.humanDate,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.schedule_rounded,
                    'Requested Time',
                    booking.scheduledTimeLabel,
                  ),
                  _divider(),
                  // Distance
                  if (widget.distanceKm > 0) ...[
                    _detailRow(
                      Icons.location_on_rounded,
                      'Distance',
                      '${widget.distanceKm.toStringAsFixed(1)} km away',
                    ),
                    _divider(),
                  ],
                  // Urgency
                  _detailRow(
                    Icons.priority_high_rounded,
                    'Urgency',
                    booking.urgency,
                  ),
                  // Submitted time
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.access_time_rounded,
                    'Submitted',
                    timeago.format(booking.createdAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool isMultiLine = false}) {
    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.neonAccent.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  height: isMultiLine ? 1.5 : 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: AppColors.glassBorder,
      ),
    );
  }

  // ─── Section 3: Decision Cards ───────────────────────────

  SliverToBoxAdapter _buildDecisionSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR DECISION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how to proceed with this request',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            _buildDecisionCard(
              index: 0,
              icon: Icons.calculate_outlined,
              title: 'Remote Estimate',
              subtitle:
                  'I have enough information to estimate this service remotely.',
              buttonLabel: 'Continue',
            ),
            const SizedBox(height: 12),
            _buildDecisionCard(
              index: 1,
              icon: Icons.search_rounded,
              title: 'Request Inspection Visit',
              subtitle:
                  'I need to inspect the client\'s installation before providing an accurate estimate.',
              buttonLabel: 'Request Visit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
  }) {
    final isSelected = _selectedDecision == index;

    return GestureDetector(
      onTap: () => _selectDecision(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonAccent.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.neonAccent.withValues(alpha: 0.4)
                : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonAccent.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.neonAccent.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected
                    ? AppColors.neonAccent
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (index == 0) {
                          // Already showing estimate builder below
                        } else {
                          _openInspectionSheet();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.neonAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          buttonLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.neonAccent
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.neonAccent
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      size: 14, color: AppColors.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section 4: Estimate Builder ─────────────────────────

  SliverToBoxAdapter _buildEstimateBuilder() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _decisionFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTIMATE BUILDER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Labor Cost
              _buildInputField(
                label: 'Labor Cost (MAD)',
                controller: _laborController,
                icon: Icons.engineering_rounded,
                hint: 'e.g. 200',
                isNumeric: true,
              ),
              const SizedBox(height: 16),

              // Material Cost
              _buildInputField(
                label: 'Material Cost (MAD)',
                controller: _materialController,
                icon: Icons.inventory_2_rounded,
                hint: 'e.g. 150',
                isNumeric: true,
              ),
              const SizedBox(height: 16),

              // Duration
              _buildInputField(
                label: 'Estimated Duration',
                controller: _durationController,
                icon: Icons.timer_outlined,
                hint: 'e.g. 1-2 hours',
                isNumeric: false,
              ),
              const SizedBox(height: 16),

              // Message
              _buildInputField(
                label: 'Message for Client (Optional)',
                controller: _messageController,
                icon: Icons.message_outlined,
                hint: 'Any extra details about pricing or parts...',
                isNumeric: false,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Live Total Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.neonAccent.withValues(alpha: 0.12),
                      AppColors.neonAccent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.neonAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Labor',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${_laborCost.toStringAsFixed(0)} MAD',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Material',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${_materialCost.toStringAsFixed(0)} MAD',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        height: 1,
                        color: AppColors.neonAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.neonAccent,
                          ),
                        ),
                        Text(
                          '${_totalCost.toStringAsFixed(0)} MAD',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neonAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Reject Request',
                      icon: Icons.close_rounded,
                      color: AppColors.error,
                      filled: false,
                      onTap: _rejectRequest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _actionButton(
                      label: 'Send Estimate',
                      icon: Icons.send_rounded,
                      color: AppColors.neonAccent,
                      filled: true,
                      onTap: _isEstimateValid ? _sendEstimate : null,
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isNumeric,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            fontSize: isNumeric ? 20 : 14,
            fontWeight: isNumeric ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.onSurface,
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.35)),
            prefixIcon: Icon(icon,
                color: AppColors.neonAccent.withValues(alpha: 0.6), size: 20),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.neonAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    final effectiveColor =
        isDisabled ? AppColors.onSurfaceVariant.withValues(alpha: 0.3) : color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: filled
              ? (isDisabled
                  ? AppColors.surfaceContainerHigh
                  : effectiveColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? effectiveColor : effectiveColor,
            width: filled ? 0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: filled
                    ? (isDisabled
                        ? AppColors.onSurfaceVariant
                        : AppColors.onPrimary)
                    : effectiveColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled
                    ? (isDisabled
                        ? AppColors.onSurfaceVariant
                        : AppColors.onPrimary)
                    : effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Fullscreen Image Viewer
// ═══════════════════════════════════════════════════════════

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.neonAccent,
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 64,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Inspection Request Bottom Sheet
// ═══════════════════════════════════════════════════════════

class _InspectionRequestSheet extends StatefulWidget {
  final BookingModel booking;
  final Function(double? fee, String message, String? date, String? time)
      onSubmit;

  const _InspectionRequestSheet({
    required this.booking,
    required this.onSubmit,
  });

  @override
  State<_InspectionRequestSheet> createState() =>
      _InspectionRequestSheetState();
}

class _InspectionRequestSheetState extends State<_InspectionRequestSheet> {
  final _feeController = TextEditingController();
  final _messageController = TextEditingController(
    text:
        'I need to inspect your installation before providing an accurate quotation.',
  );
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  bool get _isValid => _messageController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _feeController.dispose();
    _messageController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Inspection Visit',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Request an on-site visit before providing your estimate.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Visit Fee
              _label('VISIT FEE (OPTIONAL)'),
              const SizedBox(height: 8),
              _field(
                controller: _feeController,
                hint: 'e.g. 100',
                icon: Icons.payments_outlined,
                isNumeric: true,
              ),
              const SizedBox(height: 20),

              // Message
              _label('MESSAGE'),
              const SizedBox(height: 8),
              _field(
                controller: _messageController,
                hint: 'Explain why you need to inspect...',
                icon: Icons.message_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Date + Time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('PREFERRED DATE'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _dateController,
                          hint: 'e.g. Tomorrow',
                          icon: Icons.calendar_today_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('PREFERRED TIME'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _timeController,
                          hint: 'e.g. 10:00 AM',
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid
                      ? () {
                          final fee =
                              double.tryParse(_feeController.text.trim());
                          widget.onSubmit(
                            fee,
                            _messageController.text.trim(),
                            _dateController.text.trim().isNotEmpty
                                ? _dateController.text.trim()
                                : null,
                            _timeController.text.trim().isNotEmpty
                                ? _timeController.text.trim()
                                : null,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonAccent,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.surfaceContainerHigh,
                    disabledForegroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Send Inspection Request',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.onSurfaceVariant,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: isNumeric ? 20 : 14,
        fontWeight: isNumeric ? FontWeight.w700 : FontWeight.w500,
        color: AppColors.onSurface,
      ),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon,
            color: AppColors.neonAccent.withValues(alpha: 0.6), size: 20),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.neonAccent),
        ),
      ),
    );
  }
}
