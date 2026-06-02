import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// FCM Service for handling push notifications
/// Manages token generation, notification handling, and navigation
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Callback for notification clicks
  Function(String chatId, String senderId)? onNotificationClick;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[FCM] 🚀 Initializing FCM Service...');

      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] ✅ Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] ✅ User granted permission');
        
        // Initialize local notifications
        await _initializeLocalNotifications();
        
        // Get and save FCM token
        await _getAndSaveToken();
        
        // Setup token refresh listener
        _setupTokenRefreshListener();
        
        // Setup foreground notification handler
        _setupForegroundHandler();
        
        // Setup background notification handler
        _setupBackgroundHandler();
        
        // Setup notification click handler
        _setupNotificationClickHandler();
        
        debugPrint('[FCM] ✅ FCM Service initialized successfully');
      } else {
        debugPrint('[FCM] ❌ User declined permission');
      }
      
      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ Error initializing FCM: $e');
      debugPrint('[FCM] StackTrace: $stackTrace');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        debugPrint('[FCM] 🔔 Local notification clicked: ${details.payload}');
        _handleNotificationClick(details.payload);
      },
    );

    debugPrint('[FCM] ✅ Local notifications initialized');
  }

  /// Get FCM token and save to Firestore
  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      
      if (token != null) {
        debugPrint('[FCM] 🔑 Token generated: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      } else {
        debugPrint('[FCM] ❌ Failed to get token');
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Error getting token: $e');
    }
  }

  /// Save FCM token to Firestore user document
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('[FCM] ❌ No user logged in, cannot save token');
        return;
      }

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FCM] ✅ Token saved to Firestore for user: $userId');
    } catch (e) {
      debugPrint('[FCM] ❌ Error saving token: $e');
    }
  }

  /// Setup listener for token refresh
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] 🔄 Token refreshed: ${newToken.substring(0, 20)}...');
      _saveTokenToFirestore(newToken);
    });
  }

  /// Setup foreground notification handler
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
  }

  /// Setup background notification handler
  void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Setup notification click handler
  void _setupNotificationClickHandler() {
    // Handle notification click when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[FCM] 🔔 Notification clicked (background)');
      debugPrint('[FCM] Data: ${message.data}');
      debugPrint('═══════════════════════════════════════');
      
      _handleNotificationData(message.data);
    });

    // Handle notification click when app is terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('═══════════════════════════════════════');
        debugPrint('[FCM] 🔔 Notification clicked (terminated)');
        debugPrint('[FCM] Data: ${message.data}');
        debugPrint('═══════════════════════════════════════');
        
        _handleNotificationData(message.data);
      }
    });
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
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

    // Create payload with chatId and senderId
    final payload = '${message.data['chatId']}|${message.data['senderId']}';

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
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

    if (chatId != null && senderId != null) {
      debugPrint('[FCM] 🚀 Navigating to chat: $chatId');
      onNotificationClick?.call(chatId, senderId);
    } else {
      debugPrint('[FCM] ❌ Invalid notification data');
    }
  }

  /// Handle notification click from local notification
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length == 2) {
      final chatId = parts[0];
      final senderId = parts[1];
      
      debugPrint('[FCM] 🚀 Navigating to chat from local notification: $chatId');
      onNotificationClick?.call(chatId, senderId);
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('[FCM] ✅ Token deleted');
    } catch (e) {
      debugPrint('[FCM] ❌ Error deleting token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('═══════════════════════════════════════');
  debugPrint('[FCM] 📬 Background notification received');
  debugPrint('[FCM] Title: ${message.notification?.title}');
  debugPrint('[FCM] Body: ${message.notification?.body}');
  debugPrint('[FCM] Data: ${message.data}');
  debugPrint('═══════════════════════════════════════');
}
