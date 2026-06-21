import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'notification_api_service.dart';

/// ChatService handles all Firestore operations for chat functionality
/// Provides methods for sending messages, retrieving messages, and managing chats
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Generate consistent chat ID for two users
  /// CRITICAL: Always returns the same ID regardless of parameter order
  /// This is the SINGLE SOURCE OF TRUTH for chatId generation
  /// Example: generateChatId("user1", "user2") == generateChatId("user2", "user1")
  static String generateChatId(String uid1, String uid2) {
    if (uid1.isEmpty || uid2.isEmpty) {
      throw Exception('Cannot generate chatId with empty UIDs');
    }
    if (uid1 == uid2) {
      throw Exception('Cannot create chat with same user');
    }
    // Sort UIDs alphabetically to ensure consistency
    final sortedUids = [uid1, uid2]..sort();
    final chatId = '${sortedUids[0]}_${sortedUids[1]}';
    debugPrint('[ChatService] Generated chatId: $chatId from [$uid1, $uid2]');
    return chatId;
  }

  /// Send a text message
  /// CRITICAL: Uses static generateChatId to ensure consistency
  /// Creates chat document BEFORE sending message to avoid permission errors
  /// ✅ NEW: Implements WhatsApp-like unread count system
  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] 🚀 sendMessage() CALLED');
      
      // Validate input
      if (text.trim().isEmpty) {
        debugPrint('[ChatService] ❌ Validation failed: Message is empty');
        throw Exception('Message cannot be empty');
      }

      if (currentUserId.isEmpty) {
        debugPrint('[ChatService] ❌ Validation failed: User not authenticated');
        throw Exception('User not authenticated');
      }

      if (receiverId.isEmpty) {
        debugPrint('[ChatService] ❌ Validation failed: Receiver ID is empty');
        throw Exception('Receiver ID is empty');
      }

      debugPrint('[ChatService] ✅ Validation passed');

      // CRITICAL: Use static method to generate consistent chatId
      final chatId = ChatService.generateChatId(currentUserId, receiverId);

      // Debug logs
      debugPrint('[ChatService] 💬 Chat Details:');
      debugPrint('[ChatService]   Current User: $currentUserId');
      debugPrint('[ChatService]   Receiver: $receiverId');
      debugPrint('[ChatService]   Chat ID: $chatId');
      debugPrint('[ChatService]   Message: "${text.trim()}"');

      // ✅ Use batch write for atomic operations
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);

      // STEP 1: Create/update chat document with unread counts
      debugPrint('[ChatService] 💾 STEP 1: Creating/updating chat document...');
      
      final chatData = {
        'participants': [currentUserId, receiverId],
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        // ✅ NEW: Increment unread count for receiver
        'unreadCount_$receiverId': FieldValue.increment(1),
        // ✅ NEW: Reset unread count for sender (they're actively chatting)
        'unreadCount_$currentUserId': 0,
      };
      
      debugPrint('[ChatService] 📊 Unread count update:');
      debugPrint('[ChatService]   Incrementing for receiver: $receiverId');
      debugPrint('[ChatService]   Resetting for sender: $currentUserId');
      
      batch.set(chatRef, chatData, SetOptions(merge: true));

      // STEP 2: Add message to subcollection with isSeen = false
      debugPrint('[ChatService] 💾 STEP 2: Adding message to subcollection...');
      
      final messageRef = chatRef.collection('messages').doc();
      final messageData = {
        'senderId': currentUserId,
        'type': 'text',
        'text': text.trim(),
        'audioUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isSeen': false, // ✅ NEW: Default to unseen
      };
      
      debugPrint('[ChatService] Message data: $messageData');
      batch.set(messageRef, messageData);

      // Commit batch
      await batch.commit();
      
      debugPrint('[ChatService] ✅ Message sent successfully!');
      debugPrint('[ChatService] Message ID: ${messageRef.id}');
      debugPrint('[ChatService] Full path: chats/$chatId/messages/${messageRef.id}');

      // Send push notification to the receiver
      final senderName = _auth.currentUser?.displayName ?? 'Someone';
      NotificationApiService.sendPushNotification(
        receiverId: receiverId,
        title: senderName,
        body: text.trim(),
        data: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': currentUserId,
        },
      );

      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] ❌ ERROR IN sendMessage()');
      debugPrint('[ChatService] Error: $e');
      debugPrint('[ChatService] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Send media message (audio, image, video, file)
  /// Uses Cloudinary URL
  Future<void> sendMediaMessage({
    required String receiverId,
    required String type, // 'audio', 'image', 'video', 'file'
    required String mediaUrl, // Cloudinary URL
    String? fileName,
    int? duration, // For audio/video
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] 📤 sendMediaMessage() CALLED');
      debugPrint('[ChatService] Type: $type');
      debugPrint('[ChatService] Media URL: $mediaUrl');
      
      if (mediaUrl.trim().isEmpty) {
        throw Exception('Media URL cannot be empty');
      }

      if (currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final chatId = ChatService.generateChatId(currentUserId, receiverId);

      debugPrint('[ChatService] Chat ID: $chatId');
      debugPrint('[ChatService] Receiver: $receiverId');
      debugPrint('[ChatService] Current User: $currentUserId');

      // Determine last message preview
      String lastMessagePreview;
      switch (type) {
        case 'audio':
          lastMessagePreview = '🎤 Audio message';
          break;
        case 'image':
          lastMessagePreview = '📷 Photo';
          break;
        case 'video':
          lastMessagePreview = '🎥 Video';
          break;
        case 'file':
          lastMessagePreview = '📎 ${fileName ?? "File"}';
          break;
        default:
          lastMessagePreview = 'Media';
      }

      debugPrint('[ChatService] 💾 Saving to Firestore...');
      
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);
      
      // Update chat document
      batch.set(chatRef, {
        'participants': [currentUserId, receiverId],
        'lastMessage': lastMessagePreview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount_$receiverId': FieldValue.increment(1),
        'unreadCount_$currentUserId': 0,
      }, SetOptions(merge: true));

      // Create message document with mediaUrl
      final messageRef = chatRef.collection('messages').doc();
      final messageData = {
        'senderId': currentUserId,
        'type': type,
        'text': null,
        'mediaUrl': mediaUrl.trim(), // ✅ ONLY mediaUrl field
        'fileName': fileName,
        'duration': duration,
        'createdAt': FieldValue.serverTimestamp(),
        'isSeen': false,
      };

      debugPrint('[ChatService] Message data: $messageData');
      batch.set(messageRef, messageData);
      
      await batch.commit();

      debugPrint('[ChatService] ✅ $type message sent successfully');
      debugPrint('[ChatService] Message ID: ${messageRef.id}');
      debugPrint('[ChatService] Full path: chats/$chatId/messages/${messageRef.id}');

      // Send push notification to the receiver
      final senderName = _auth.currentUser?.displayName ?? 'Someone';
      NotificationApiService.sendPushNotification(
        receiverId: receiverId,
        title: senderName,
        body: lastMessagePreview,
        data: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': currentUserId,
        },
      );

      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] ❌ ERROR sending $type message');
      debugPrint('[ChatService] Error: $e');
      debugPrint('[ChatService] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// Get real-time stream of messages for a chat
  /// Returns messages ordered by createdAt in ascending order (oldest first)
  /// Use with StreamBuilder for real-time updates
  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    // Only log stream initialization once
    debugPrint('[ChatService] 👂 Starting message stream for: $chatId');
    
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      // Only log when there are actual changes
      if (snapshot.docChanges.isNotEmpty) {
        debugPrint('[ChatService] 📬 Stream update: ${snapshot.docs.length} messages (${snapshot.docChanges.length} changes)');
        
        // Log only new messages
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            debugPrint('[ChatService] ➕ New message: ${data['text']} (from: ${data['senderId']})');
          }
        }
      }
      
      return snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Check if chat exists
  Future<bool> chatExists(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[ChatService] Error checking chat existence: $e');
      return false;
    }
  }

  /// Get chat document
  Future<DocumentSnapshot?> getChat(String chatId) async {
    try {
      return await _firestore.collection('chats').doc(chatId).get();
    } catch (e) {
      debugPrint('[ChatService] Error getting chat: $e');
      return null;
    }
  }

  /// Create initial chat document
  /// Useful for creating chat before first message
  Future<void> createChat({
    required String otherUserId,
  }) async {
    try {
      // CRITICAL: Use static method to generate consistent chatId
      final chatId = ChatService.generateChatId(currentUserId, otherUserId);
      
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[ChatService] Chat created successfully: $chatId');
    } catch (e) {
      debugPrint('[ChatService] Error creating chat: $e');
      rethrow;
    }
  }

  /// Get all chats for current user
  /// Returns stream of chats where user is a participant
  Stream<QuerySnapshot> getUserChats() {
    if (currentUserId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Enhanced diagnostic method for troubleshooting real-time issues
  Future<void> diagnosticChatAccess(String chatId) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('[ChatService] 🔍 DIAGNOSTIC: Starting chat access test');
    debugPrint('[ChatService] 🔍 DIAGNOSTIC: Chat ID: $chatId');
    debugPrint('[ChatService] 🔍 DIAGNOSTIC: Current User: $currentUserId');
    debugPrint('═══════════════════════════════════════');
    
    try {
      // Test 1: Check if chat document exists and user has access
      debugPrint('[ChatService] 🔍 TEST 1: Checking chat document access...');
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      debugPrint('[ChatService] 🔍 Chat document exists: ${chatDoc.exists}');
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final participants = List<String>.from(chatData['participants'] ?? []);
        debugPrint('[ChatService] 🔍 Chat participants: $participants');
        debugPrint('[ChatService] 🔍 User in participants: ${participants.contains(currentUserId)}');
        debugPrint('[ChatService] 🔍 Last message: ${chatData['lastMessage']}');
        debugPrint('[ChatService] 🔍 Last message time: ${chatData['lastMessageTime']}');
        
        if (!participants.contains(currentUserId)) {
          debugPrint('[ChatService] ❌ ISSUE FOUND: Current user NOT in participants array!');
          debugPrint('[ChatService] ❌ This will cause Firestore rules to block access');
        }
      } else {
        debugPrint('[ChatService] ❌ ISSUE FOUND: Chat document does not exist!');
      }
      
      // Test 2: Check messages subcollection access
      debugPrint('[ChatService] 🔍 TEST 2: Checking messages subcollection...');
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(10)
          .get();
      
      debugPrint('[ChatService] 🔍 Messages count: ${messagesQuery.docs.length}');
      
      for (var i = 0; i < messagesQuery.docs.length; i++) {
        final doc = messagesQuery.docs[i];
        final data = doc.data();
        debugPrint('[ChatService] 🔍 Message $i:');
        debugPrint('[ChatService] 🔍   ID: ${doc.id}');
        debugPrint('[ChatService] 🔍   Text: ${data['text']}');
        debugPrint('[ChatService] 🔍   Sender: ${data['senderId']}');
        debugPrint('[ChatService] 🔍   Type: ${data['type']}');
        debugPrint('[ChatService] 🔍   CreatedAt: ${data['createdAt']}');
      }
      
      // Test 3: Test real-time listener
      debugPrint('[ChatService] 🔍 TEST 3: Testing real-time listener...');
      final stream = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots();
      
      final subscription = stream.listen(
        (snapshot) {
          debugPrint('[ChatService] 🔍 ✅ Real-time update received!');
          debugPrint('[ChatService] 🔍 Messages in update: ${snapshot.docs.length}');
          debugPrint('[ChatService] 🔍 Document changes: ${snapshot.docChanges.length}');
          for (var change in snapshot.docChanges) {
            debugPrint('[ChatService] 🔍 Change type: ${change.type}');
            debugPrint('[ChatService] 🔍 Changed doc: ${change.doc.id}');
          }
        },
        onError: (error) {
          debugPrint('[ChatService] 🔍 ❌ Stream error: $error');
          debugPrint('[ChatService] 🔍 This indicates a Firestore rules or permission issue');
        },
      );
      
      // Cancel diagnostic listener after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        subscription.cancel();
        debugPrint('[ChatService] 🔍 Diagnostic test completed');
        debugPrint('═══════════════════════════════════════');
      });
      
    } catch (e, stackTrace) {
      debugPrint('[ChatService] 🔍 ❌ DIAGNOSTIC ERROR: $e');
      debugPrint('[ChatService] 🔍 StackTrace: $stackTrace');
      debugPrint('[ChatService] 🔍 This indicates a Firestore rules or authentication issue');
      debugPrint('═══════════════════════════════════════');
    }
  }

  /// Delete a message
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      debugPrint('[ChatService] Message deleted successfully');
    } catch (e) {
      debugPrint('[ChatService] Error deleting message: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Mark all messages from other user as seen
  /// Called when user opens ChatScreen
  /// Uses efficient batch update to mark multiple messages at once
  Future<void> markMessagesAsSeen({
    required String chatId,
    required String otherUserId,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] 👁️ markMessagesAsSeen() CALLED');
      debugPrint('[ChatService] Chat ID: $chatId');
      debugPrint('[ChatService] Other User: $otherUserId');
      debugPrint('[ChatService] Current User: $currentUserId');

      // Query unseen messages from other user
      final unseenMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('isSeen', isEqualTo: false)
          .get();

      if (unseenMessages.docs.isEmpty) {
        debugPrint('[ChatService] ✅ No unseen messages to mark');
        debugPrint('═══════════════════════════════════════');
        return;
      }

      debugPrint('[ChatService] 📊 Found ${unseenMessages.docs.length} unseen messages');

      // Use batch write for efficiency
      final batch = _firestore.batch();
      
      for (var doc in unseenMessages.docs) {
        batch.update(doc.reference, {'isSeen': true});
        debugPrint('[ChatService] ✅✅ Marking message ${doc.id} as seen');
      }

      await batch.commit();
      
      debugPrint('[ChatService] ✅ Successfully marked ${unseenMessages.docs.length} messages as seen');
      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] ❌ ERROR IN markMessagesAsSeen()');
      debugPrint('[ChatService] Error: $e');
      debugPrint('[ChatService] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// ✅ NEW: Reset unread count for current user
  /// Called when user opens ChatScreen
  Future<void> resetUnreadCount(String chatId) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] 🔄 resetUnreadCount() CALLED');
      debugPrint('[ChatService] Chat ID: $chatId');
      debugPrint('[ChatService] Current User: $currentUserId');

      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount_$currentUserId': 0,
      });

      debugPrint('[ChatService] ✅ Unread count reset to 0 for user: $currentUserId');
      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ChatService] ❌ ERROR IN resetUnreadCount()');
      debugPrint('[ChatService] Error: $e');
      debugPrint('[ChatService] StackTrace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
      rethrow;
    }
  }

  /// ✅ NEW: Get unread count for current user in a specific chat
  /// Used to display badge in MessagesScreen
  int getUnreadCount(Map<String, dynamic> chatData) {
    try {
      final unreadCount = chatData['unreadCount_$currentUserId'] as int? ?? 0;
      return unreadCount;
    } catch (e) {
      debugPrint('[ChatService] Error getting unread count: $e');
      return 0;
    }
  }
}
