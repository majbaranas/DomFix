import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A clean, production-ready service for communicating locally with an ESP32.
class ESP32Service {
  // Singleton pattern for easy global access
  ESP32Service._();
  static final ESP32Service instance = ESP32Service._();
  factory ESP32Service() => instance;

  // Hardcoded ESP32 Local IP address
  static const String _baseUrl = 'http://192.168.137.250';
  
  // Timeout for local network requests to prevent hanging UI
  static const Duration _timeout = Duration(seconds: 3);

  /// Helper to send HTTP POST requests
  Future<bool> _sendCommand(String device, bool value, {double? numValue}) async {
    try {
      final url = Uri.parse('$_baseUrl/control');
      final body = {
        'device': device,
        'action': 'toggle',
        'value': value,
      };
      
      if (numValue != null) {
        body['numValue'] = numValue;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        debugPrint('✅ ESP32 Success: $device set to $value');
        return true;
      } else {
        debugPrint('❌ ESP32 Error: Server returned ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⏳ ESP32 Error: Connection timed out. Is the ESP32 online?');
      return false;
    } on SocketException {
      debugPrint('🔌 ESP32 Error: No route to host. Ensure you are on the same WiFi.');
      return false;
    } catch (e) {
      debugPrint('⚠️ ESP32 Error: $e');
      return false;
    }
  }

  /// Toggle the Smart Light
  Future<bool> toggleLED(bool isOn, {double? brightness}) {
    return _sendCommand('ESP32_LED', isOn, numValue: brightness);
  }

  /// Toggle the Smart Fan
  Future<bool> toggleFan(bool isOn, {double? speed}) {
    return _sendCommand('ESP32_FAN', isOn, numValue: speed);
  }

  /// Control the Smart Door (Servo)
  Future<bool> controlServo(bool isOpen) {
    return _sendCommand('ESP32_SERVO', isOpen);
  }

  /// Get the full status of all devices
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/status');
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ ESP32 Error: Failed to fetch status. Code: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('⏳ ESP32 Error: Connection timed out. Is the ESP32 online?');
      return null;
    } on SocketException {
      debugPrint('🔌 ESP32 Error: No route to host. Ensure you are on the same WiFi.');
      return null;
    } catch (e) {
      debugPrint('⚠️ ESP32 Error: $e');
      return null;
    }
  }
}
