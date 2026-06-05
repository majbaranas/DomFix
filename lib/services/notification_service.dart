import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentReference<Map<String, dynamic>>> createNotification({
    required String recipientId,
    required String senderId,
    required String type,
    required String title,
    required String body,
    String? bookingId,
    String? chatId,
    String? jobId,
    String? status,
    String? serviceName,
    String? urgency,
    Map<String, dynamic>? metadata,
  }) async {
    if (recipientId.trim().isEmpty) {
      throw ArgumentError.value(recipientId, 'recipientId');
    }
    if (senderId.trim().isEmpty) {
      throw ArgumentError.value(senderId, 'senderId');
    }

    final notificationRef = _firestore.collection('notifications').doc();
    await notificationRef.set({
      'recipientId': recipientId.trim(),
      'senderId': senderId.trim(),
      'type': type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'bookingId': bookingId,
      'chatId': chatId,
      'jobId': jobId,
      'status': status,
      'serviceName': serviceName,
      'urgency': urgency,
      'metadata': metadata ?? const <String, dynamic>{},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return notificationRef;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserNotifications({
    String? recipientId,
    int limit = 50,
  }) {
    final userId = recipientId ?? _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<int> watchUnreadCount({String? recipientId}) {
    final userId = recipientId ?? _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return Stream<int>.empty();
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead({String? recipientId}) async {
    final userId = recipientId ?? _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final unread = await _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ─── Booking Lifecycle Notification Helpers ─────────────

  Future<void> sendBookingAcceptedNotification({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
    String? chatId,
  }) async {
    await createNotification(
      recipientId: clientId,
      senderId: technicianId,
      type: 'booking_accepted',
      title: 'Booking accepted',
      body: '$technicianName accepted your $serviceName booking.',
      bookingId: bookingId,
      chatId: chatId,
      status: 'accepted',
      serviceName: serviceName,
    );
  }

  Future<void> sendBookingRejectedNotification({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
    String? chatId,
  }) async {
    await createNotification(
      recipientId: clientId,
      senderId: technicianId,
      type: 'booking_rejected',
      title: 'Booking declined',
      body: '$technicianName declined your $serviceName request.',
      bookingId: bookingId,
      chatId: chatId,
      status: 'rejected',
      serviceName: serviceName,
    );
  }

  Future<void> sendTechnicianOnTheWayNotification({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    String? chatId,
  }) async {
    await createNotification(
      recipientId: clientId,
      senderId: technicianId,
      type: 'technician_on_way',
      title: 'Technician is on the way',
      body: '$technicianName is heading to your location.',
      bookingId: bookingId,
      chatId: chatId,
      status: 'on_the_way',
    );
  }

  Future<void> sendJobStartedNotification({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
    String? chatId,
  }) async {
    await createNotification(
      recipientId: clientId,
      senderId: technicianId,
      type: 'job_started',
      title: 'Job started',
      body: '$technicianName has started working on your $serviceName.',
      bookingId: bookingId,
      chatId: chatId,
      status: 'in_progress',
      serviceName: serviceName,
    );
  }

  Future<void> sendJobCompletedNotification({
    required String bookingId,
    required String clientId,
    required String technicianId,
    required String technicianName,
    required String serviceName,
    String? chatId,
  }) async {
    await createNotification(
      recipientId: clientId,
      senderId: technicianId,
      type: 'job_completed',
      title: 'Job completed',
      body: 'Your $serviceName job has been completed successfully.',
      bookingId: bookingId,
      chatId: chatId,
      status: 'completed',
      serviceName: serviceName,
    );
  }
}
