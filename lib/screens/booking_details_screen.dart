import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_colors.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingModel booking;
  final double? distanceKm;
  final int? etaMinutes;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.distanceKm,
    this.etaMinutes,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _isSubmitting = false;

  void _showQuoteBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuoteBottomSheet(
        booking: widget.booking,
        onSubmit: (price, duration, note) async {
          Navigator.pop(context); // close sheet
          setState(() => _isSubmitting = true);
          try {
            await BookingService.instance.sendQuote(
              bookingId: widget.booking.id,
              clientId: widget.booking.clientId,
              technicianId: widget.booking.technicianId,
              technicianName: widget.booking.technicianName,
              serviceName: widget.booking.serviceName,
              price: price,
              duration: duration,
              note: note,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Quote sent successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context); // return to jobs screen
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send quote: $e'),
                  backgroundColor: AppColors.error,
                ),
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Booking Request',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.booking.normalizedStatus == 'pending_quote' 
                                ? AppColors.warning.withValues(alpha: 0.12)
                                : AppColors.neonAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.booking.normalizedStatus == 'pending_quote'
                                ? Icons.pending_actions_rounded
                                : Icons.check_circle_rounded,
                            color: widget.booking.normalizedStatus == 'pending_quote'
                                ? AppColors.warning
                                : AppColors.neonAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.booking.normalizedStatus == 'pending_quote'
                                    ? 'Awaiting Your Quote'
                                    : 'Quote Sent',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Requested ${timeago.format(widget.booking.createdAt)}',
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
                  ),
                  const SizedBox(height: 24),

                  // Service info
                  Text(
                    'SERVICE REQUESTED',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.booking.serviceName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Detail chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(
                        icon: Icons.calendar_today_rounded,
                        label: widget.booking.scheduledTimeLabel,
                      ),
                      _DetailChip(
                        icon: Icons.priority_high_rounded,
                        label: widget.booking.urgency,
                        color: widget.booking.urgency == 'Emergency' 
                            ? AppColors.error 
                            : AppColors.neonAccent,
                      ),
                      if (widget.distanceKm != null && widget.distanceKm! > 0)
                        _DetailChip(
                          icon: Icons.location_on_rounded,
                          label: '${widget.distanceKm!.toStringAsFixed(1)} km away',
                        ),
                      if (widget.etaMinutes != null && widget.etaMinutes! > 0)
                        _DetailChip(
                          icon: Icons.directions_car_rounded,
                          label: '${widget.etaMinutes} min ETA',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'DESCRIPTION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.booking.description,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Photos
                  if (widget.booking.imageUrls.isNotEmpty) ...[
                    Text(
                      'PHOTOS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.booking.imageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final url = widget.booking.imageUrls[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: url.isNotEmpty
                                ? Image.network(
                                    url,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 120,
                                      height: 120,
                                      color: AppColors.surfaceContainerHigh,
                                      child: Icon(Icons.broken_image_rounded,
                                          color: AppColors.onSurfaceVariant, size: 28),
                                    ),
                                  )
                                : Container(
                                    width: 120,
                                    height: 120,
                                    color: AppColors.surfaceContainerHigh,
                                    child: Icon(Icons.image_not_supported_rounded,
                                        color: AppColors.onSurfaceVariant, size: 28),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: widget.booking.normalizedStatus == 'pending_quote' && !_isSubmitting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _showQuoteBottomSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonAccent,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Review & Send Quote',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBottomSheet extends StatefulWidget {
  final BookingModel booking;
  final Function(double price, String duration, String note) onSubmit;

  const _QuoteBottomSheet({required this.booking, required this.onSubmit});

  @override
  State<_QuoteBottomSheet> createState() => _QuoteBottomSheetState();
}

class _QuoteBottomSheetState extends State<_QuoteBottomSheet> {
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _noteController = TextEditingController();

  bool get _isValid {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final duration = _durationController.text.trim();
    return price > 0 && duration.isNotEmpty;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Send Quote',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Price Input
            Text(
              'ESTIMATED PRICE (MAD)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. 150',
                hintStyle: GoogleFonts.spaceGrotesk(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.neonAccent),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.neonAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Duration Input
            Text(
              'ESTIMATED DURATION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.onSurface,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. 1-2 hours',
                hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.timer_outlined, color: AppColors.neonAccent),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.neonAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Note Input
            Text(
              'NOTE FOR CLIENT (OPTIONAL)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Any extra details about pricing or parts...',
                hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.neonAccent),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () {
                        widget.onSubmit(
                          double.parse(_priceController.text.trim()),
                          _durationController.text.trim(),
                          _noteController.text.trim(),
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
                  'Send Quote to Client',
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
    );
  }
}
