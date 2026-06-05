import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import 'chat_service.dart';

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
    final chatId = chatIdFor(clientId, technicianId);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (chatDoc.exists) {
      return;
    }

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
    required int estimatedDurationMinutes,
    required double estimatedPriceMin,
    required double estimatedPriceMax,
    required double technicianFee,
    required double platformFee,
  }) async {
    final chatId = chatIdFor(clientId, technicianId);
    final bookingRef = bookingId == null
        ? _firestore.collection('bookings').doc()
        : _firestore.collection('bookings').doc(bookingId);

    // Verify availability before creating
    final available = await isSlotAvailable(
      technicianId: technicianId,
      scheduledAt: scheduledAt,
    );
    if (!available) {
      throw Exception(
        'This time slot is already reserved. Please choose another available time.',
      );
    }

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
      status: 'pending',
      imageUrls: imageUrls,
      estimatedDurationMinutes: estimatedDurationMinutes,
      estimatedPriceMin: estimatedPriceMin,
      estimatedPriceMax: estimatedPriceMax,
      technicianFee: technicianFee,
      platformFee: platformFee,
      createdAt: DateTime.now(),
    );

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
        'bookingStatus': 'pending',
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
        'status': 'pending',
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
        'status': 'pending',
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

    await batch.commit();
    return booking;
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
    final chatId = chatIdFor(clientId, technicianId);

    final notificationData = _notificationForStatus(
      newStatus: newStatus,
      technicianName: technicianName,
      serviceName: serviceName,
    );

    final batch = _firestore.batch();

    // Update booking status
    batch.update(
      _firestore.collection('bookings').doc(bookingId),
      {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Update chat booking status
    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'bookingStatus': newStatus,
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
        'status': newStatus,
        'serviceName': serviceName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Map<String, String>? _notificationForStatus({
    required String newStatus,
    required String technicianName,
    required String serviceName,
  }) {
    switch (newStatus) {
      case 'accepted':
        return {
          'type': 'booking_accepted',
          'title': 'Booking accepted',
          'body': '$technicianName accepted your $serviceName booking.',
        };
      case 'rejected':
        return {
          'type': 'booking_rejected',
          'title': 'Booking declined',
          'body': '$technicianName declined your $serviceName request.',
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
      case 'completed':
        return {
          'type': 'job_completed',
          'title': 'Job completed',
          'body': 'Your $serviceName job has been completed successfully.',
        };
      default:
        return null;
    }
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
