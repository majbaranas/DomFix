import 'package:cloud_firestore/cloud_firestore.dart';

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
    final bookingRefFirestore = bookingRef;
    final chatRef = _firestore.collection('chats').doc(chatId);
    final clientNotificationRef = _firestore.collection('notifications').doc();
    final technicianNotificationRef =
        _firestore.collection('notifications').doc();

    batch.set(bookingRefFirestore, booking.toFirestore());
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
}
