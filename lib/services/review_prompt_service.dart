import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/review_service.dart';
import '../widgets/review_rating_modal.dart';

class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  StreamSubscription<List<BookingModel>>? _subscription;
  BuildContext? _context;
  final Set<String> _shownReviews = {};

  void startMonitoring(BuildContext context, String clientId) {
    stopMonitoring();
    _context = context;
    _subscription = ReviewService.instance
        .watchPendingBookingReviews(clientId)
        .listen((bookings) {
      if (bookings.isEmpty) return;
      
      for (final booking in bookings) {
        if (!_shownReviews.contains(booking.id)) {
          _shownReviews.add(booking.id);
          _showReviewModal(booking);
          break;
        }
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _context = null;
  }

  void _showReviewModal(BookingModel booking) {
    if (_context == null || !_context!.mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_context == null || !_context!.mounted) return;
      
      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (context) => ReviewRatingModal(
          booking: booking,
          onComplete: () {
            _shownReviews.remove(booking.id);
          },
        ),
      );
    });
  }

  void clearShownReviews() {
    _shownReviews.clear();
  }
}
