import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/booking_model.dart';
import '../services/review_service.dart';

class ReviewRatingModal extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onComplete;

  const ReviewRatingModal({
    super.key,
    required this.booking,
    required this.onComplete,
  });

  @override
  State<ReviewRatingModal> createState() => _ReviewRatingModalState();
}

class _ReviewRatingModalState extends State<ReviewRatingModal> with SingleTickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a rating', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ReviewService.instance.submitBookingReview(
        booking: widget.booking,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you for your review!', style: GoogleFonts.inter()),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _skipReview() async {
    setState(() => _submitting = true);
    try {
      await ReviewService.instance.skipBookingReview(widget.booking.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonAccent.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.neonAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Job Completed!',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How was your experience with ${widget.booking.technicianName}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: _submitting ? null : () => setState(() => _rating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: starValue <= _rating ? AppColors.neonAccent : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _getRatingText(_rating),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonAccent,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 500,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _submitting ? null : _skipReview,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
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
                      onTap: _submitting ? null : _submitReview,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _rating == 0 ? AppColors.surface : AppColors.neonAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Submit Review',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _rating == 0 ? AppColors.onSurfaceVariant : AppColors.onPrimary,
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
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
