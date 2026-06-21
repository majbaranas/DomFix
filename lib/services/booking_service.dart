import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import 'chat_service.dart';
import 'review_service.dart';

class BookingService {
  BookingService._();

  static final BookingService instance = BookingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String newBookingId() => _firestore.collection('bookings').doc().id;

  String chatIdFor(String clientId, String technicianId) {
    return ChatService.generateChatId(clientId, technicianId);
  }

  // ─── Availability Methods ───────────────────────────────

  /// Returns a real-time stream of booked [TimeOfDay] slots for a technician
  /// on a specific date. Used by the booking flow to grey out taken slots.
  Stream<List<TimeOfDay>> watchBookedSlots({
    required String technicianId,
    required DateTime date,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .snapshots()
        .map((snapshot) {
      final bookedTimes = <TimeOfDay>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? 'pending').toLowerCase();
        // Only block slots that are actively booked (not cancelled/rejected)
        if (status == 'cancelled' || status == 'rejected') continue;
        final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
        if (scheduledAt != null) {
          bookedTimes.add(TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute));
        }
      }
      return bookedTimes;
    });
  }

  /// One-shot query for booked slots on a given date.
  Future<List<TimeOfDay>> getBookedSlotsForDate({
    required String technicianId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    final bookedTimes = <TimeOfDay>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? 'pending').toLowerCase();
      if (status == 'cancelled' || status == 'rejected') continue;
      final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
      if (scheduledAt != null) {
        bookedTimes.add(TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute));
      }
    }
    return bookedTimes;
  }

  /// Checks if a specific time slot is available for a technician.
  Future<bool> isSlotAvailable({
    required String technicianId,
    required DateTime scheduledAt,
  }) async {
    final dayStart = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? 'pending').toLowerCase();
      if (status == 'cancelled' || status == 'rejected') continue;
      final bookedAt = (data['scheduledAt'] as Timestamp?)?.toDate();
      if (bookedAt != null &&
          bookedAt.hour == scheduledAt.hour &&
          bookedAt.minute == scheduledAt.minute) {
        return false;
      }
    }
    return true;
  }

  // ─── Conversation Shell ─────────────────────────────────

  Future<void> ensureConversationShell({
    required String clientId,
    required String technicianId,
    required String technicianName,
  }) async {
    print('[BookingService] 🔵 ensureConversationShell called');
    print('[BookingService]   clientId: $clientId');
    print('[BookingService]   technicianId: $technicianId');
    print('[BookingService]   technicianName: $technicianName');
    
    final chatId = chatIdFor(clientId, technicianId);
    print('[BookingService]   chatId: $chatId');
    
    final chatRef = _firestore.collection('chats').doc(chatId);
    
    try {
      print('[BookingService] 📖 Checking if chat exists...');
      final chatDoc = await chatRef.get();
      
      if (chatDoc.exists) {
        print('[BookingService] ✅ Chat already exists, skipping creation');
        return;
      }
      
      print('[BookingService] 📝 Chat does not exist, creating new chat shell...');
      await chatRef.set({
        'participants': [clientId, technicianId],
        'clientId': clientId,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'bookingStatus': 'none',
        'accessLevel': 'limited',
        'canShareImages': false,
        'canUseVoiceNotes': false,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('[BookingService] ✅ Chat shell created successfully');
    } catch (e, stackTrace) {
      print('[BookingService] ❌ ERROR in ensureConversationShell: $e');
      print('[BookingService] StackTrace: $stackTrace');
      rethrow;
    }
  }

  // ─── Access Check ───────────────────────────────────────

  Future<bool> hasFullAccess({
    required String clientId,
    required String technicianId,
  }) async {
    final chatId = chatIdFor(clientId, technicianId);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      return false;
    }
    final data = doc.data() ?? <String, dynamic>{};
    final accessLevel = data['accessLevel'] as String? ?? 'limited';
    final bookingStatus = data['bookingStatus'] as String? ?? 'none';
    return accessLevel == 'full' ||
        bookingStatus == 'pending' ||
        bookingStatus == 'confirmed' ||
        bookingStatus == 'accepted' ||
        bookingStatus == 'on_the_way' ||
        bookingStatus == 'arrived' ||
        bookingStatus == 'in_progress' ||
        bookingStatus == 'completed';
  }

  // ─── Create Booking (Transaction-Safe) ──────────────────

  Future<BookingModel> createBooking({
    String? bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceId,
    required String serviceName,
    required DateTime scheduledAt,
    required String scheduledTimeLabel,
    required String description,
    required String urgency,
    required List<String> imageUrls,
    double? clientLat,
    double? clientLng,
    int estimatedDurationMinutes = 60,
    double estimatedPriceMin = 0,
    double estimatedPriceMax = 0,
    double technicianFee = 0,
    double platformFee = 0,
  }) async {
    print('[BookingService] 🔵 createBooking called');
    print('[BookingService]   clientId: $clientId');
    print('[BookingService]   technicianId: $technicianId');
    print('[BookingService]   serviceName: $serviceName');
    print('[BookingService]   scheduledAt: $scheduledAt');
    
    final chatId = chatIdFor(clientId, technicianId);
    print('[BookingService]   chatId: $chatId');
    
    final bookingRef = bookingId == null
        ? _firestore.collection('bookings').doc()
        : _firestore.collection('bookings').doc(bookingId);
    print('[BookingService]   bookingId: ${bookingRef.id}');

    // Verify availability before creating
    print('[BookingService] 🔍 Checking slot availability...');
    final available = await isSlotAvailable(
      technicianId: technicianId,
      scheduledAt: scheduledAt,
    );
    
    if (!available) {
      print('[BookingService] ❌ Slot not available');
      throw Exception(
        'This time slot is already reserved. Please choose another available time.',
      );
    }
    print('[BookingService] ✅ Slot is available');

    final booking = BookingModel(
      id: bookingRef.id,
      chatId: chatId,
      clientId: clientId,
      technicianId: technicianId,
      participants: [clientId, technicianId],
      technicianName: technicianName,
      serviceId: serviceId,
      serviceName: serviceName,
      scheduledAt: scheduledAt,
      scheduledTimeLabel: scheduledTimeLabel,
      description: description,
      urgency: urgency,
      status: 'pending_quote',
      imageUrls: imageUrls,
      estimatedDurationMinutes: estimatedDurationMinutes,
      estimatedPriceMin: estimatedPriceMin,
      estimatedPriceMax: estimatedPriceMax,
      technicianFee: technicianFee,
      platformFee: platformFee,
      createdAt: DateTime.now(),
      clientLat: clientLat,
      clientLng: clientLng,
    );

    print('[BookingService] 📝 Creating batch write...');
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final clientNotificationRef = _firestore.collection('notifications').doc();
    final technicianNotificationRef =
        _firestore.collection('notifications').doc();

    batch.set(bookingRef, booking.toFirestore());
    batch.set(
      chatRef,
      {
        'participants': [clientId, technicianId],
        'clientId': clientId,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'bookingId': booking.id,
        'bookingStatus': 'pending_quote',
        'accessLevel': 'full',
        'canShareImages': true,
        'canUseVoiceNotes': true,
        'lastMessage': 'Booking request sent for $serviceName',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      clientNotificationRef,
      {
        'recipientId': clientId,
        'senderId': clientId,
        'type': 'booking_submitted',
        'title': 'Booking request sent',
        'body':
            'We sent your $serviceName request to $technicianName and unlocked chat.',
        'bookingId': booking.id,
        'chatId': chatId,
        'status': 'pending_quote',
        'serviceName': serviceName,
        'urgency': urgency,
        'metadata': {
          'scheduledTimeLabel': scheduledTimeLabel,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      technicianNotificationRef,
      {
        'recipientId': technicianId,
        'senderId': clientId,
        'type': 'booking_request',
        'title': 'New booking request',
        'body': '$serviceName requested for $scheduledTimeLabel',
        'bookingId': booking.id,
        'chatId': chatId,
        'status': 'pending_quote',
        'serviceName': serviceName,
        'urgency': urgency,
        'metadata': {
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'description': description,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    try {
      print('[BookingService] 💾 Committing batch...');
      await batch.commit();
      print('[BookingService] ✅ Booking created successfully');
      return booking;
    } catch (e, stackTrace) {
      print('[BookingService] ❌ ERROR committing batch: $e');
      print('[BookingService] StackTrace: $stackTrace');
      rethrow;
    }
  }

  // ─── Booking Status Updates ─────────────────────────────

  /// Updates booking status and creates a notification for the client.
  Future<void> updateBookingStatus({
    required String bookingId,
    required String newStatus,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
  }) async {
    print('[BookingService] 🔄 Updating booking status to: $newStatus');
    
    final chatId = chatIdFor(clientId, technicianId);
    final normalizedStatus = newStatus.trim().toLowerCase().replaceAll(' ', '_');

    final notificationData = _notificationForStatus(
      newStatus: normalizedStatus,
      technicianName: technicianName,
      serviceName: serviceName,
    );

    final batch = _firestore.batch();

    // Update booking status
    batch.update(
      _firestore.collection('bookings').doc(bookingId),
      {
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Update chat booking status
    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'bookingStatus': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Create notification for client
    if (notificationData != null) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'recipientId': clientId,
        'senderId': technicianId,
        'type': notificationData['type'],
        'title': notificationData['title'],
        'body': notificationData['body'],
        'bookingId': bookingId,
        'chatId': chatId,
        'status': normalizedStatus,
        'serviceName': serviceName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('[BookingService] ✅ Booking status updated');
    
    // If status changed to 'completed', increment technician's completed jobs
    if (normalizedStatus == 'completed') {
      print('[BookingService] 🎉 Job completed! Incrementing counter...');
      ReviewService.incrementCompletedJobs(technicianId);
    }
  }

  Map<String, String>? _notificationForStatus({
    required String newStatus,
    required String technicianName,
    required String serviceName,
  }) {
    switch (newStatus) {
      case 'quote_sent':
        return {
          'type': 'quote_sent',
          'title': 'Estimate Received',
          'body': '$technicianName sent an estimate for your $serviceName request.',
        };
      case 'accepted':
        return {
          'type': 'booking_accepted',
          'title': 'Booking accepted',
          'body': 'You accepted the estimate for $serviceName.',
        };
      case 'rejected':
        return {
          'type': 'booking_rejected',
          'title': 'Booking declined',
          'body': 'The $serviceName request was declined.',
        };
      case 'on_the_way':
        return {
          'type': 'technician_on_way',
          'title': 'Technician is on the way',
          'body': '$technicianName is heading to your location.',
        };
      case 'in_progress':
        return {
          'type': 'job_started',
          'title': 'Job started',
          'body': '$technicianName has started working on your $serviceName.',
        };
      case 'completed_pending_confirmation':
        return {
          'type': 'job_completed_pending',
          'title': 'Job completed',
          'body': '$technicianName finished the job. Please confirm.',
        };
      case 'completed':
        return {
          'type': 'job_completed',
          'title': 'Job confirmed',
          'body': 'Your $serviceName job has been completed successfully.',
        };
      default:
        return null;
    }
  }

  // ─── Marketplace Actions ────────────────────────────────

  Future<void> sendQuote({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
    required double price,
    required String duration,
    String? note,
  }) async {
    final chatId = chatIdFor(clientId, technicianId);
    final batch = _firestore.batch();

    batch.update(_firestore.collection('bookings').doc(bookingId), {
      'status': 'quote_sent',
      'technicianEstimatedPrice': price,
      'technicianEstimatedDuration': duration,
      if (note != null && note.isNotEmpty) 'technicianNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_firestore.collection('chats').doc(chatId), {
      'bookingStatus': 'quote_sent',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': clientId,
      'senderId': technicianId,
      'type': 'quote_sent',
      'title': 'Estimate Received',
      'body': '$technicianName sent an estimate for your $serviceName request.',
      'bookingId': bookingId,
      'chatId': chatId,
      'status': 'quote_sent',
      'serviceName': serviceName,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> acceptQuote({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
  }) async {
    await updateBookingStatus(
      bookingId: bookingId,
      newStatus: 'accepted',
      clientId: clientId,
      technicianId: technicianId,
      technicianName: technicianName,
      serviceName: serviceName,
    );
  }

  Future<void> rejectQuote({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
  }) async {
    await updateBookingStatus(
      bookingId: bookingId,
      newStatus: 'rejected',
      clientId: clientId,
      technicianId: technicianId,
      technicianName: technicianName,
      serviceName: serviceName,
    );
  }

  Future<void> confirmCompletion({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
  }) async {
    await updateBookingStatus(
      bookingId: bookingId,
      newStatus: 'completed',
      clientId: clientId,
      technicianId: technicianId,
      technicianName: technicianName,
      serviceName: serviceName,
    );
  }

  // ─── Query Methods ──────────────────────────────────────

  Future<BookingModel?> getLatestBookingBetweenUsers({
    required String clientId,
    required String technicianId,
  }) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: clientId)
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return BookingModel.fromFirestore(snapshot.docs.first);
  }

  /// Streams all bookings for a technician, sorted by priority.
  Stream<List<BookingModel>> watchTechnicianBookings(String technicianId) {
    return _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();
      bookings.sort((a, b) => a.compareByPriority(b));
      return bookings;
    });
  }
}
