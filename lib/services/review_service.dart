import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking_model.dart';
import '../models/review_model.dart';
import 'firebase_storage_service.dart';
import 'technician_ranking_service.dart';

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
    print('[ReviewService] 🔵 submitBookingReview called');
    print('[ReviewService]   bookingId: ${booking.id}');
    print('[ReviewService]   technicianId: ${booking.technicianId}');
    print('[ReviewService]   rating: $rating');
    print('[ReviewService]   comment length: ${comment.length}');
    
    final user = _auth.currentUser;
    if (user == null) {
      print('[ReviewService] ❌ User not authenticated');
      throw Exception('Please sign in to review this job.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be 1-5.');
    }

    print('[ReviewService]   clientId: ${user.uid}');
    print('[ReviewService]   clientName: ${user.displayName}');
    
    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final reviewRef = _firestore.collection('reviews').doc(booking.id);
    final cleanedComment = comment.trim();

    try {
      print('[ReviewService] 📝 Step 1: Creating review document...');
      
      // Step 1: Create review document in transaction
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
      
      print('[ReviewService] ✅ Review document created');
      
      // Step 2: Aggregate stats client-side
      print('[ReviewService] 📊 Step 2: Calculating stats...');
      await _aggregateTechnicianStats(booking.technicianId);
      
      print('[ReviewService] ✅ Review submission complete!');
    } catch (e, stackTrace) {
      print('[ReviewService] ❌ ERROR submitting review: $e');
      print('[ReviewService] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Client-side stats aggregation (replaces Cloud Function)
  Future<void> _aggregateTechnicianStats(String technicianId) async {
    print('[ReviewService] 📊 Aggregating stats for technician: $technicianId');
    
    try {
      // Fetch ALL reviews for this technician
      print('[ReviewService] 🔍 Fetching all reviews...');
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('technicianId', isEqualTo: technicianId)
          .get();
      
      print('[ReviewService] 📦 Found ${reviewsSnapshot.docs.length} reviews');

      // Calculate aggregated stats
      int ratingSum = 0;
      int totalReviews = 0;
      double qualityScoreSum = 0.0;

      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final reviewRating = (data['rating'] as num?)?.toInt() ?? 0;
        final reviewComment = (data['comment'] as String?)?.trim() ?? '';
        
        ratingSum += reviewRating;
        totalReviews += 1;
        
        // Quality bonus: longer meaningful comments = better quality
        final commentBonus = reviewComment.length >= 12 ? 0.2 : 0.0;
        qualityScoreSum += (reviewRating / 5.0) + commentBonus;
      }

      final averageRating = totalReviews > 0 
          ? double.parse((ratingSum / totalReviews).toStringAsFixed(2))
          : 0.0;
      
      final reviewQualityScore = totalReviews > 0
          ? double.parse((qualityScoreSum / totalReviews).toStringAsFixed(2))
          : 0.0;

      print('[ReviewService] 📊 Calculated stats:');
      print('[ReviewService]   Average Rating: $averageRating');
      print('[ReviewService]   Total Reviews: $totalReviews');
      print('[ReviewService]   Quality Score: $reviewQualityScore');

      // Get current stats
      print('[ReviewService] 🔍 Fetching current stats...');
      final statsDoc = await _firestore
          .collection('technician_stats')
          .doc(technicianId)
          .get();
      
      final currentStats = statsDoc.data() ?? <String, dynamic>{};
      final completedJobs = (currentStats['completedJobs'] as num?)?.toInt() ?? 0;
      final profileCompletionBonus = (currentStats['profileCompletionBonus'] as num?)?.toDouble() ?? 0.0;
      final responseSpeedScore = (currentStats['responseSpeedScore'] as num?)?.toDouble() ?? 0.0;
      final profileCompletenessScore =
          (currentStats['profileCompletenessScore'] as num?)?.toDouble() ??
          profileCompletionBonus;
      final activityScore = (currentStats['activityScore'] as num?)?.toDouble() ?? 100.0;
      final availabilityScore = (currentStats['availabilityScore'] as num?)?.toDouble() ?? 0.0;
      final availabilityEnabled = currentStats['availabilityEnabled'] != false;

      final rankScore = TechnicianRankingService.calculateRankScore(
        averageRating: averageRating,
        totalReviews: totalReviews,
        completedJobs: completedJobs,
        responseSpeedScore: responseSpeedScore,
        profileCompletenessScore: profileCompletenessScore,
        activityScore: activityScore,
        availabilityScore: availabilityScore,
        availabilityEnabled: availabilityEnabled,
      );

      print('[ReviewService]   Completed Jobs: $completedJobs');
      print('[ReviewService]   Rank Score: $rankScore');

      // Step 3: Update both collections in a batch
      print('[ReviewService] 💾 Updating technician_stats and users...');
      final batch = _firestore.batch();

      // Update technician_stats
      batch.set(
        _firestore.collection('technician_stats').doc(technicianId),
        {
          'technicianId': technicianId,
          'averageRating': averageRating,
          'totalReviews': totalReviews,
          'completedJobs': completedJobs,
          'ratingSum': ratingSum,
          'reviewQualityScore': reviewQualityScore,
          'profileCompletionBonus': profileCompletionBonus,
          'profileCompletenessScore': profileCompletenessScore,
          'activityScore': 100.0,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'rankScore': rankScore,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Update users collection (for backward compatibility)
      batch.set(
        _firestore.collection('users').doc(technicianId),
        {
          'rating': averageRating,
          'averageRating': averageRating,
          'reviewCount': totalReviews,
          'jobsCompleted': completedJobs,
          'profileCompletionScore': profileCompletenessScore,
          'activityScore': 100.0,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'rankScore': rankScore,
          'updatedAt': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      print('[ReviewService] ✅ Stats updated successfully!');
      
    } catch (e, stackTrace) {
      print('[ReviewService] ❌ ERROR aggregating stats: $e');
      print('[ReviewService] StackTrace: $stackTrace');
      // Don't rethrow - review is already created, stats can be fixed later
    }
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

  /// Increment completed jobs count when booking is marked as completed
  /// Call this from BookingService when status changes to 'completed'
  static Future<void> incrementCompletedJobs(String technicianId) async {
    if (technicianId.trim().isEmpty) return;
    
    print('[ReviewService] 🎉 Incrementing completed jobs for: $technicianId');
    
    try {
      final firestore = FirebaseFirestore.instance;
      final statsRef = firestore.collection('technician_stats').doc(technicianId);
      
      await firestore.runTransaction((transaction) async {
        final statsSnap = await transaction.get(statsRef);
        final currentStats = statsSnap.exists ? statsSnap.data()! : <String, dynamic>{};
        
        final completedJobs = ((currentStats['completedJobs'] as num?)?.toInt() ?? 0) + 1;
        final averageRating = (currentStats['averageRating'] as num?)?.toDouble() ?? 0.0;
        final totalReviews = (currentStats['totalReviews'] as num?)?.toInt() ?? 0;
        final reviewQualityScore = (currentStats['reviewQualityScore'] as num?)?.toDouble() ?? 0.0;
        final ratingSum = (currentStats['ratingSum'] as num?)?.toInt() ?? 0;
        final profileCompletionBonus = (currentStats['profileCompletionBonus'] as num?)?.toDouble() ?? 0.0;
        final profileCompletenessScore =
            (currentStats['profileCompletenessScore'] as num?)?.toDouble() ??
            profileCompletionBonus;
        final responseSpeedScore = (currentStats['responseSpeedScore'] as num?)?.toDouble() ?? 0.0;
        final activityScore = (currentStats['activityScore'] as num?)?.toDouble() ?? 100.0;
        final availabilityScore = (currentStats['availabilityScore'] as num?)?.toDouble() ?? 0.0;
        final availabilityEnabled = currentStats['availabilityEnabled'] != false;
        
        final rankScore = TechnicianRankingService.calculateRankScore(
          averageRating: averageRating,
          totalReviews: totalReviews,
          completedJobs: completedJobs,
          responseSpeedScore: responseSpeedScore,
          profileCompletenessScore: profileCompletenessScore,
          activityScore: activityScore,
          availabilityScore: availabilityScore,
          availabilityEnabled: availabilityEnabled,
        );
        
        // Update technician_stats
        transaction.set(statsRef, {
          'technicianId': technicianId,
          'completedJobs': completedJobs,
          'averageRating': averageRating,
          'totalReviews': totalReviews,
          'ratingSum': ratingSum,
          'reviewQualityScore': reviewQualityScore,
          'profileCompletionBonus': profileCompletionBonus,
          'profileCompletenessScore': profileCompletenessScore,
          'activityScore': 100.0,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'rankScore': rankScore,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Update users collection
        transaction.set(
          firestore.collection('users').doc(technicianId),
          {
            'jobsCompleted': completedJobs,
            'rating': averageRating,
            'averageRating': averageRating,
            'reviewCount': totalReviews,
            'profileCompletionScore': profileCompletenessScore,
            'activityScore': 100.0,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'rankScore': rankScore,
            'updatedAt': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      
      print('[ReviewService] ✅ Completed jobs incremented to ${(await statsRef.get()).data()?['completedJobs']}');
    } catch (e, stackTrace) {
      print('[ReviewService] ❌ ERROR incrementing completed jobs: $e');
      print('[ReviewService] StackTrace: $stackTrace');
      // Don't rethrow - this is a background operation
    }
  }

  static double _qualityScore(int rating, String comment) {
    final commentBonus = comment.trim().length >= 12 ? 0.2 : 0.0;
    return (rating / 5.0) + commentBonus;
  }
}
