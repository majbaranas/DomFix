import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NotificationApiService {
  // ═══════════════════════════════════════════════════════════
  // IMPORTANT: Set this to your backend URL
  // ─────────────────────────────────────────────────────────
  // For REAL DEVICES on local network:
  //   Use your computer's LAN IP, e.g. 'http://192.168.1.x:3000'
  //   Find it with: ipconfig (Windows) or ifconfig (Mac/Linux)
  //
  // For EMULATOR:
  //   Use 'http://10.0.2.2:3000'
  //
  // For PRODUCTION (deployed backend):
  //   Use your deployed URL, e.g. 'https://domfix-backend.onrender.com'
  // ═══════════════════════════════════════════════════════════
  static const String _baseUrl = 'http://10.33.96.218:3000';

  static const String _notifyEndpoint = '$_baseUrl/api/notify';
  static const Duration _timeout = Duration(seconds: 10);

  /// Sends a push notification via the Node.js backend
  static Future<bool> sendPushNotification({
    required String receiverId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[NotificationAPI] 🚀 Sending push notification');
      debugPrint('[NotificationAPI]   Receiver: $receiverId');
      debugPrint('[NotificationAPI]   Title: $title');
      debugPrint('[NotificationAPI]   Body: $body');
      debugPrint('[NotificationAPI]   Endpoint: $_notifyEndpoint');

      final response = await http
          .post(
            Uri.parse(_notifyEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'receiverId': receiverId,
              'title': title,
              'body': body,
              'data': data ?? {},
            }),
          )
          .timeout(_timeout);

      final responseBody = response.body;
      debugPrint('[NotificationAPI] Response: ${response.statusCode} — $responseBody');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        if (decoded['success'] == true) {
          debugPrint('[NotificationAPI] ✅ Push sent successfully to $receiverId');
          debugPrint('[NotificationAPI]   FCM Message ID: ${decoded['messageId']}');
        } else {
          debugPrint('[NotificationAPI] ⚠️ Backend returned success=false: ${decoded['message']}');
        }
        return decoded['success'] == true;
      } else {
        debugPrint('[NotificationAPI] ❌ Failed to send push: ${response.statusCode}');
        debugPrint('[NotificationAPI]   Response body: $responseBody');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationAPI] ❌ Error calling backend: $e');
      debugPrint('[NotificationAPI]   Endpoint was: $_notifyEndpoint');
      debugPrint('[NotificationAPI]   Make sure the backend is running and reachable from this device');
      return false;
    } finally {
      debugPrint('═══════════════════════════════════════');
    }
  }

  /// Check if the backend is reachable (health check)
  static Future<bool> checkBackendHealth() async {
    try {
      debugPrint('[NotificationAPI] 🏥 Checking backend health at $_baseUrl...');
      final response = await http.get(Uri.parse(_baseUrl)).timeout(_timeout);

      if (response.statusCode == 200) {
        debugPrint('[NotificationAPI] ✅ Backend is reachable: ${response.body}');
        return true;
      } else {
        debugPrint('[NotificationAPI] ❌ Backend returned status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationAPI] ❌ Backend is NOT reachable: $e');
      debugPrint('[NotificationAPI]   URL: $_baseUrl');
      debugPrint('[NotificationAPI]   Possible causes:');
      debugPrint('[NotificationAPI]     - Backend not running (run: cd backend && node index.js)');
      debugPrint('[NotificationAPI]     - Wrong IP address (check ipconfig)');
      debugPrint('[NotificationAPI]     - Firewall blocking port 3000');
      debugPrint('[NotificationAPI]     - Device not on same WiFi network');
      return false;
    }
  }
}
