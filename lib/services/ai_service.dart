import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiConversationTurn {
  final String role;
  final String content;

  const AiConversationTurn({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class AiChatResult {
  final String reply;
  final String proTip;
  final String specialist;
  final String model;
  final bool streamed;
  final Map<String, dynamic>? usage;

  const AiChatResult({
    required this.reply,
    required this.proTip,
    required this.specialist,
    required this.model,
    required this.streamed,
    this.usage,
  });

  factory AiChatResult.fromJson(
    Map<String, dynamic> json, {
    bool streamed = false,
  }) {
    return AiChatResult(
      reply: (json['reply'] ?? '').toString().trim(),
      proTip: (json['proTip'] ?? '').toString().trim(),
      specialist: (json['specialist'] ?? '').toString().trim(),
      model: (json['model'] ?? '').toString().trim(),
      streamed: streamed,
      usage: json['usage'] is Map<String, dynamic>
          ? json['usage'] as Map<String, dynamic>
          : null,
    );
  }
}

class AiServiceException implements Exception {
  final String code;
  final String message;
  final bool retryable;

  const AiServiceException({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  @override
  String toString() => 'AiServiceException($code): $message';
}

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  factory AiService() => instance;

  static const Duration _timeout = Duration(seconds: 40);
  static const int _maxAttempts = 2;
  http.Client? _activeClient;

  void cancelCurrentRequest() {
    _activeClient?.close();
    _activeClient = null;
  }

  /// Direct Groq API key — development fallback only.
  /// In production, the backend proxies all AI requests.
  String get _groqApiKey {
    const key = String.fromEnvironment('DOMFIX_GROQ_API_KEY', defaultValue: '');
    return key;
  }

  /// Returns true when using direct Groq mode (dev only).
  bool get _isDirectGroq => _groqApiKey.isNotEmpty;

  /// Backend URL — configurable via dart-define.
  /// Priority: DOMFIX_BACKEND_URL > DOMFIX_AI_BASE_URL > localhost:3000
  String get _baseUrl {
    // 1. Explicit backend URL (production)
    const backendUrl = String.fromEnvironment(
      'DOMFIX_BACKEND_URL',
      defaultValue: '',
    );
    if (backendUrl.isNotEmpty) {
      return backendUrl.endsWith('/')
          ? backendUrl.substring(0, backendUrl.length - 1)
          : backendUrl;
    }

    // 2. Legacy override
    const legacyOverride = String.fromEnvironment(
      'DOMFIX_AI_BASE_URL',
      defaultValue: '',
    );
    if (legacyOverride.isNotEmpty) {
      return legacyOverride.endsWith('/')
          ? legacyOverride.substring(0, legacyOverride.length - 1)
          : legacyOverride;
    }

    // 3. Direct Groq mode (development only)
    if (_isDirectGroq) {
      return 'https://api.groq.com/openai/v1/chat/completions';
    }

    // 4. Default: local backend (using host machine's Wi-Fi IP for physical devices)
    debugPrint('[AiService] ⚠️ No DOMFIX_BACKEND_URL set — using http://192.168.1.188:3000 (local dev)');
    return 'http://192.168.1.188:3000';
  }

  Uri _endpoint(String path) {
    if (_isDirectGroq) {
      return Uri.parse(_baseUrl);
    }
    return Uri.parse('$_baseUrl/$path');
  }

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in again to use the AI assistant.');
    }

    return await user.getIdToken() ?? '';
  }

  Future<AiChatResult> sendConversation({
    required List<AiConversationTurn> messages,
    void Function(String partialReply)? onStreamDelta,
  }) async {
    if (messages.isEmpty) {
      throw const AiServiceException(
        code: 'empty_conversation',
        message: 'Conversation cannot be empty.',
      );
    }

    final isDirectGroq = _isDirectGroq;
    final token = isDirectGroq ? _groqApiKey : await _getIdToken();
    
    debugPrint('[AiService] Mode: ${isDirectGroq ? "Direct Groq (dev)" : "Backend proxy"}');
    debugPrint('[AiService] Base URL: $_baseUrl');

    // Convert to OpenAI format for direct Groq API
    final payload = isDirectGroq 
        ? {
            'model': 'llama3-70b-8192',
            'messages': messages.map((m) => m.toJson()).toList(),
            'stream': onStreamDelta != null,
          }
        : {
            'messages': messages.map((message) => message.toJson()).toList(),
          };

    if (onStreamDelta != null) {
      try {
        return await _sendStreaming(payload, token, onStreamDelta, isDirectGroq);
      } catch (error) {
        final normalized = normalizeError(error);

        if (normalized.code == 'cancelled') {
          throw normalized;
        }

        if (normalized.code == 'network' || normalized.code == 'stream_closed') {
          debugPrint('[AiService] Streaming failed, falling back to JSON: $normalized');
        } else {
          throw normalized;
        }
      }
    }

    return _sendJson(payload, token, isDirectGroq);
  }

  AiChatResult _parseResult(Map<String, dynamic> decoded, bool isDirectGroq, {bool streamed = false}) {
    if (!isDirectGroq) {
      return AiChatResult.fromJson(decoded, streamed: streamed);
    }
    
    final choices = decoded['choices'] as List<dynamic>?;
    final message = choices?.isNotEmpty == true ? choices![0]['message'] as Map<String, dynamic>? : null;
    final content = message?['content'] as String? ?? '';
    
    return AiChatResult(
      reply: content.trim(),
      proTip: '',
      specialist: 'DomFix',
      model: decoded['model']?.toString() ?? 'llama3-70b',
      streamed: streamed,
      usage: decoded['usage'] as Map<String, dynamic>?,
    );
  }

  Future<AiChatResult> _sendJson(Map<String, dynamic> payload, String token, bool isDirectGroq) async {
    final uri = isDirectGroq ? _endpoint('') : _endpoint('api/ai/chat');

    // --- DEBUG LOGGING ---
    debugPrint('================ AI SERVICE REQUEST (JSON) ================');
    debugPrint('Request URL: $uri');
    debugPrint('Direct Groq Mode: $isDirectGroq');
    debugPrint('Method: POST');
    debugPrint('Authorization: Bearer ${token.length > 8 ? '${token.substring(0, 4)}****${token.substring(token.length - 4)}' : '****'}');
    debugPrint('===========================================================');

    final response = await _withRetry(() async {
      return http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // --- DEBUG ERROR LOGGING ---
      debugPrint('================ AI SERVICE ERROR (JSON) ================');
      debugPrint('Request URL: $uri');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      debugPrint('=========================================================');

      throw AiServiceException(
        code: 'http_${response.statusCode}',
        message: _extractErrorMessage(response.body),
        retryable: response.statusCode >= 500 || response.statusCode == 429,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = _parseResult(decoded, isDirectGroq);

    if (result.reply.isEmpty) {
      debugPrint('[AiService] ⚠️ Empty reply. Response body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      throw const AiServiceException(
        code: 'empty_response',
        message: 'The AI service returned an empty response.',
        retryable: true,
      );
    }

    debugPrint('[AiService] ✅ JSON response received (${result.reply.length} chars, model: ${result.model})');
    return result;
  }

  Future<AiChatResult> _sendStreaming(
    Map<String, dynamic> payload,
    String token,
    void Function(String partialReply) onStreamDelta,
    bool isDirectGroq,
  ) async {
    String lastPartial = '';
    AiChatResult? finalResult;
    bool sawStreamPayloadError = false;

    try {
      final client = http.Client();
      _activeClient = client;
      try {
        final uri = isDirectGroq ? _endpoint('') : _endpoint('api/ai/chat/stream');
        
        // --- DEBUG LOGGING ---
        debugPrint('================ AI SERVICE REQUEST ================');
        debugPrint('Base URL: $_baseUrl');
        debugPrint('Endpoint: $uri');
        debugPrint('Direct Groq Mode: $isDirectGroq');
        debugPrint('Authorization Header: Bearer ${token.length > 8 ? '${token.substring(0, 4)}****${token.substring(token.length - 4)}' : '****'}');
        debugPrint('Method: POST');
        debugPrint('Headers: {Content-Type: application/json, Accept: text/event-stream}');
        debugPrint('====================================================');

        final response = await _withRetry(() {
          final request = http.Request('POST', uri)
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode(payload);

          return client.send(request).timeout(_timeout);
        });

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await response.stream.bytesToString();
          
          // --- DEBUG LOGGING ---
          debugPrint('================ AI SERVICE ERROR ================');
          debugPrint('Request URL: $uri');
          debugPrint('Method: POST');
          debugPrint('Status Code: ${response.statusCode}');
          debugPrint('Response Body: $body');
          debugPrint('==================================================');

          throw AiServiceException(
            code: 'http_${response.statusCode}',
            message: _extractErrorMessage(body),
            retryable: response.statusCode >= 500 || response.statusCode == 429,
          );
        }

        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('text/event-stream')) {
          final body = await response.stream.bytesToString();
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          final result = _parseResult(decoded, isDirectGroq, streamed: true);
          if (result.reply.isNotEmpty) {
            onStreamDelta(result.reply);
          }
          return result;
        }

        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (!line.startsWith('data:')) {
            continue;
          }

          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') {
            continue;
          }

          try {
            final parsed = jsonDecode(data) as Map<String, dynamic>;
            
            if (isDirectGroq) {
               final choices = parsed['choices'] as List<dynamic>?;
               if (choices != null && choices.isNotEmpty) {
                 final delta = choices[0]['delta'] as Map<String, dynamic>?;
                 if (delta != null && delta['content'] != null) {
                   lastPartial += delta['content'] as String;
                   onStreamDelta(lastPartial);
                 }
               }
            } else {
               if (parsed['reply'] is String) {
                 lastPartial = parsed['reply'] as String;
                 onStreamDelta(lastPartial);
               }

               if (parsed['error'] != null) {
                 sawStreamPayloadError = true;
                 throw AiServiceException(
                   code: 'stream_error',
                   message: parsed['error'].toString(),
                   retryable: true,
                 );
               }

               if (parsed['proTip'] != null ||
                   parsed['specialist'] != null ||
                   parsed['usage'] != null ||
                   parsed['model'] != null) {
                 final candidate = AiChatResult.fromJson(parsed, streamed: true);
                 finalResult = candidate.reply.isNotEmpty
                     ? candidate
                     : AiChatResult(
                         reply: lastPartial,
                         proTip: candidate.proTip,
                         specialist: candidate.specialist,
                         model: candidate.model,
                         streamed: true,
                         usage: candidate.usage,
                       );
               }
            }
          } catch (error) {
            debugPrint('[AiService] Ignoring malformed stream chunk: $error');
            if (sawStreamPayloadError) {
              rethrow;
            }
          }
        }
      } finally {
        client.close();
        if (_activeClient == client) {
          _activeClient = null;
        }
      }
    } catch (error) {
      final normalized = normalizeError(error);
      debugPrint('[AiService] Stream request failed: $normalized');

      if (normalized.code == 'cancelled') {
        throw normalized;
      }

      if (normalized.code != 'network' && normalized.code != 'stream_closed') {
        throw normalized;
      }

      final fallback = await _sendJson(payload, token, isDirectGroq);
      if (fallback.reply.isNotEmpty) {
        onStreamDelta(fallback.reply);
      }
      return fallback;
    }

    if (finalResult != null) {
      final result = finalResult;
      if (result.reply.isNotEmpty && result.reply != lastPartial) {
        onStreamDelta(result.reply);
      }
      return result;
    }

    final fallback = await _sendJson(payload, token, isDirectGroq);
    if (fallback.reply.isNotEmpty) {
      onStreamDelta(fallback.reply);
    }
    return fallback;
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts || !_isRetriable(error)) {
          break;
        }

        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    throw normalizeError(lastError ?? StateError('Request failed.'));
  }

  bool _isRetriable(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('429');
  }

  String _extractErrorMessage(String body) {
    debugPrint('[AiService] Raw error body: ${body.length > 500 ? body.substring(0, 500) : body}');
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        final errorValue = decoded['error'];
        if (errorValue is Map<String, dynamic> && errorValue['message'] != null) {
          return errorValue['message'].toString();
        }
        return errorValue.toString();
      }
    } catch (_) {
      // Fall through to a generic message.
    }

    return 'The AI service is temporarily unavailable. Please try again in a moment.';
  }

  AiServiceException normalizeError(Object error, [StackTrace? stackTrace]) {
    if (error is AiServiceException) {
      return error;
    }

    final message = error.toString();
    final lower = message.toLowerCase();
    final retryable = lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('429') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504');

    // --- DEBUG LOGGING ---
    debugPrint('================ AI SERVICE EXCEPTION ================');
    debugPrint('Error: $message');
    debugPrint('Retryable: $retryable');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    } else {
      debugPrint('StackTrace: ${StackTrace.current}');
    }
    debugPrint('======================================================');

    if (lower.contains('canceled') ||
        lower.contains('cancelled') ||
        lower.contains('err_canceled')) {
      return const AiServiceException(
        code: 'cancelled',
        message: 'Request cancelled.',
        retryable: false,
      );
    }

    if (lower.contains('sign in') || lower.contains('auth')) {
      return AiServiceException(
        code: 'auth',
        message: 'Please sign in again to use the AI assistant.',
      );
    }

    return AiServiceException(
      code: retryable ? 'network' : 'unknown',
      message: message,
      retryable: retryable,
    );
  }
}
