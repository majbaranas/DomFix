import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking_model.dart';
import '../models/review_model.dart';
import 'firebase_storage_service.dart';

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  Stream<List<BookingModel>> watchPendingBookingReviews(String clientId) {
    if (clientId.trim().isEmpty) {
      return const Stream<List<BookingModel>>.empty();
    }

    return _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .asyncMap((snapshot) async {
      final candidates = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final reviewStatus =
                (data['reviewStatus'] ?? 'pending').toString().trim();
            return reviewStatus != 'submitted' && reviewStatus != 'skipped';
          })
          .map(BookingModel.fromFirestore)
          .toList();

      if (candidates.isEmpty) return const <BookingModel>[];

      final pending = <BookingModel>[];
      for (final booking in candidates) {
        final review = await _firestore
            .collection('reviews')
            .doc(booking.id)
            .get();
        if (!review.exists) {
          pending.add(booking);
        }
      }

      pending.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      return pending;
    });
  }

  Future<void> submitBookingReview({
    required BookingModel booking,
    required int rating,
    String comment = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to review this job.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be 1-5.');
    }

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final reviewRef = _firestore.collection('reviews').doc(booking.id);
    final cleanedComment = comment.trim();

    await _firestore.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw Exception('Booking not found.');
      }

      final bookingData = bookingSnap.data() ?? const <String, dynamic>{};
      final status = (bookingData['status'] ?? '').toString().toLowerCase();
      final clientId = (bookingData['clientId'] ?? '').toString();
      if (status != 'completed') {
        throw Exception('Only completed jobs can be reviewed.');
      }
      if (clientId != user.uid) {
        throw Exception('Only the booked client can review this job.');
      }

      final reviewSnap = await transaction.get(reviewRef);
      if (reviewSnap.exists) {
        throw Exception('This job has already been reviewed.');
      }

      transaction.set(reviewRef, {
        'bookingId': booking.id,
        'clientId': user.uid,
        'technicianId': booking.technicianId,
        'rating': rating,
        'comment': cleanedComment,
        'serviceName': booking.serviceName,
        'clientName': user.displayName ?? '',
        'clientPhotoUrl': user.photoURL ?? '',
        'reviewQualityScore': _qualityScore(rating, cleanedComment),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(bookingRef, {
        'reviewStatus': 'submitted',
        'reviewId': booking.id,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> skipBookingReview(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to continue.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final reviewRef = _firestore.collection('reviews').doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) return;

      final data = bookingSnap.data() ?? const <String, dynamic>{};
      final status = (data['status'] ?? '').toString().toLowerCase();
      final clientId = (data['clientId'] ?? '').toString();
      if (status != 'completed' || clientId != user.uid) return;

      final reviewSnap = await transaction.get(reviewRef);
      if (reviewSnap.exists) return;

      transaction.update(bookingRef, {
        'reviewStatus': 'skipped',
        'reviewSkippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<TechnicianReview>> watchTechnicianReviews(
    String technicianId, {
    int limit = 20,
  }) {
    if (technicianId.trim().isEmpty) {
      return const Stream<List<TechnicianReview>>.empty();
    }

    return _firestore
        .collection('reviews')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(TechnicianReview.fromDoc).toList());
  }

  Stream<TechnicianStats> watchTechnicianStats(String technicianId) {
    if (technicianId.trim().isEmpty) {
      return Stream.value(TechnicianStats.empty(technicianId));
    }

    return _firestore
        .collection('technician_stats')
        .doc(technicianId)
        .snapshots()
        .map((doc) => doc.exists
            ? TechnicianStats.fromDoc(doc)
            : TechnicianStats.empty(technicianId));
  }

  Stream<List<CompletedJobPhoto>> watchTechnicianWorkPhotos(
    String technicianId, {
    int limit = 20,
  }) {
    if (technicianId.trim().isEmpty) {
      return const Stream<List<CompletedJobPhoto>>.empty();
    }

    return _firestore
        .collection('completed_job_photos')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CompletedJobPhoto.fromDoc).toList());
  }

  Future<List<String>> uploadCompletionPhotosForBooking({
    required BookingModel booking,
    required List<File> photos,
    String kind = 'result',
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != booking.technicianId || photos.isEmpty) {
      return const <String>[];
    }

    final urls = <String>[];
    for (final photo in photos) {
      final url = await _storageService.uploadBookingImage(
        bookingId: booking.id,
        imageFile: photo,
      );
      urls.add(url);

      await _firestore.collection('completed_job_photos').add({
        'bookingId': booking.id,
        'clientId': booking.clientId,
        'technicianId': booking.technicianId,
        'imageUrl': url,
        'kind': kind,
        'serviceName': booking.serviceName,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _firestore.collection('bookings').doc(booking.id).set({
      'completionPhotoUrls': FieldValue.arrayUnion(urls),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return urls;
  }

  static double _qualityScore(int rating, String comment) {
    final commentBonus = comment.trim().length >= 12 ? 0.2 : 0.0;
    return (rating / 5.0) + commentBonus;
  }
}
