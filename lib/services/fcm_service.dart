import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler — MUST be a top-level function.
/// Runs in a separate isolate when app is in background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // CRITICAL: Firebase must be initialized in background isolate
  await Firebase.initializeApp();

  debugPrint('═══════════════════════════════════════');
  debugPrint('[FCM Background] 📬 Background notification received');
  debugPrint('[FCM Background] Title: ${message.notification?.title}');
  debugPrint('[FCM Background] Body: ${message.notification?.body}');
  debugPrint('[FCM Background] Data: ${message.data}');
  debugPrint('═══════════════════════════════════════');
}

/// FCM Service for handling push notifications
/// Manages token generation, notification handling, and navigation
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Callback for notification clicks
  Function(String chatId, String senderId)? onNotificationClick;

  /// The single notification channel used across the entire app.
  /// Must match the channelId sent by the backend and the
  /// default_notification_channel_id in AndroidManifest.xml.
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'DomFix Notifications';
  static const String _channelDescription =
      'Important notifications for bookings, chats, and updates';

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[FCM] 🚀 Initializing FCM Service...');

      // Step 1: Request notification permissions (iOS + Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
          '[FCM] ✅ Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] ✅ User granted notification permission');

        // Step 2: Initialize local notifications + create channel
        await _initializeLocalNotifications();

        // Step 3: Get and save FCM token
        await _getAndSaveToken();

        // Step 4: Setup token refresh listener
        _setupTokenRefreshListener();

        // Step 5: Setup foreground notification handler
        _setupForegroundHandler();

        // Step 6: Setup notification click handlers
        _setupNotificationClickHandler();

        debugPrint('[FCM] ✅ FCM Service initialized successfully');
      } else {
        debugPrint('[FCM] ❌ User declined notification permission');
        debugPrint(
            '[FCM] ⚠️ Notifications will NOT work without permission');
      }

      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ Error initializing FCM: $e');
      debugPrint('[FCM] StackTrace: $stackTrace');
    }
  }

  /// Initialize local notifications for foreground display.
  /// CRITICAL: Creates the Android notification channel programmatically.
  /// On Android 8.0+ (API 26+), channels must be created before notifications
  /// can be shown. Without this, all notifications are silently dropped.
  Future<void> _initializeLocalNotifications() async {
    // ── Android settings ──
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ── iOS settings ──
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint(
            '[FCM] 🔔 Local notification clicked: ${details.payload}');
        _handleNotificationClick(details.payload);
      },
    );

    // ── CRITICAL: Create the Android notification channel ──
    // This MUST be done before any notification is shown on Android 8.0+
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Create the high-importance notification channel
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      debugPrint('[FCM] ✅ Android notification channel created: $_channelId');

      // Request notification permission on Android 13+ (API 33+)
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('[FCM] 🔔 Android 13+ notification permission: $granted');
    }

    debugPrint('[FCM] ✅ Local notifications initialized');
  }

  /// Get FCM token and save to Firestore
  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();

      if (token != null) {
        debugPrint(
            '[FCM] 🔑 Token generated: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      } else {
        debugPrint('[FCM] ❌ Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Error getting token: $e');
    }
  }

  /// Save FCM token to Firestore user document.
  /// Uses set+merge instead of update to handle both new and existing documents.
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        debugPrint('[FCM] ❌ No user logged in, cannot save token');
        return;
      }

      // Use set with merge — works for both new and existing documents
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] ✅ Token saved to Firestore for user: $userId');
    } catch (e) {
      debugPrint('[FCM] ❌ Error saving token: $e');
    }
  }

  /// Setup listener for token refresh
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint(
          '[FCM] 🔄 Token refreshed: ${newToken.substring(0, 20)}...');
      _saveTokenToFirestore(newToken);
    });
    debugPrint('[FCM] ✅ Token refresh listener registered');
  }

  /// Setup foreground notification handler.
  /// When a notification arrives while the app is open, we must show
  /// a local notification manually (FCM doesn't show banners in foreground).
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[FCM] 📬 Foreground notification received');
      debugPrint('[FCM] Title: ${message.notification?.title}');
      debugPrint('[FCM] Body: ${message.notification?.body}');
      debugPrint('[FCM] Data: ${message.data}');
      debugPrint('═══════════════════════════════════════');

      // Show local notification when app is in foreground
      _showLocalNotification(message);
    });
    debugPrint('[FCM] ✅ Foreground handler registered');
  }

  /// Setup notification click handler for background/terminated app opens
  void _setupNotificationClickHandler() {
    // Handle notification click when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[FCM] 🔔 Notification clicked (background)');
      debugPrint('[FCM] Data: ${message.data}');
      debugPrint('═══════════════════════════════════════');

      _handleNotificationData(message.data);
    });

    // Handle notification click when app was terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('═══════════════════════════════════════');
        debugPrint('[FCM] 🔔 Notification clicked (terminated)');
        debugPrint('[FCM] Data: ${message.data}');
        debugPrint('═══════════════════════════════════════');

        // Delay slightly to ensure navigation stack is ready
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationData(message.data);
        });
      }
    });
    debugPrint('[FCM] ✅ Notification click handlers registered');
  }

  /// Show local notification for foreground messages.
  /// This is what makes notifications appear like WhatsApp when the app is open.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create payload with chatId and senderId for navigation on tap
    final payload =
        '${message.data['chatId'] ?? ''}|${message.data['senderId'] ?? ''}';

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'DomFix',
      message.notification?.body ?? '',
      details,
      payload: payload,
    );

    debugPrint('[FCM] ✅ Local notification shown');
  }

  /// Handle notification data and navigate
  void _handleNotificationData(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final senderId = data['senderId'] as String?;

    if (chatId != null &&
        chatId.isNotEmpty &&
        senderId != null &&
        senderId.isNotEmpty) {
      debugPrint('[FCM] 🚀 Navigating to chat: $chatId');
      onNotificationClick?.call(chatId, senderId);
    } else {
      debugPrint(
          '[FCM] ℹ️ Notification tapped but no chat data (type: ${data['type']})');
    }
  }

  /// Handle notification click from local notification
  void _handleNotificationClick(String? payload) {
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      final chatId = parts[0];
      final senderId = parts[1];

      debugPrint(
          '[FCM] 🚀 Navigating to chat from local notification: $chatId');
      onNotificationClick?.call(chatId, senderId);
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    try {
      // Clear from Firestore first
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        });
        debugPrint('[FCM] ✅ Token cleared from Firestore for user: $userId');
      }

      // Then delete from FCM
      await _messaging.deleteToken();
      debugPrint('[FCM] ✅ FCM token deleted');
    } catch (e) {
      debugPrint('[FCM] ❌ Error deleting token: $e');
    }
  }
}
