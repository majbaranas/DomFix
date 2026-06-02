const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Send FCM notification when new message is created
 * Trigger: chats/{chatId}/messages/{messageId}
 * 
 * Flow:
 * 1. Get message data (senderId, text)
 * 2. Extract receiverId from chatId
 * 3. Fetch receiver's FCM token from Firestore
 * 4. Send push notification via FCM
 */
exports.sendMessageNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      console.log('═══════════════════════════════════════');
      console.log('[FCM Function] 🚀 New message detected');
      
      const chatId = context.params.chatId;
      const messageId = context.params.messageId;
      const messageData = snapshot.data();
      
      console.log('[FCM Function] Chat ID:', chatId);
      console.log('[FCM Function] Message ID:', messageId);
      console.log('[FCM Function] Sender ID:', messageData.senderId);
      console.log('[FCM Function] Message text:', messageData.text);
      
      // Extract participant IDs from chatId (format: uid1_uid2)
      const participants = chatId.split('_');
      
      if (participants.length !== 2) {
        console.error('[FCM Function] ❌ Invalid chatId format:', chatId);
        return null;
      }
      
      // Determine receiver (the participant who is NOT the sender)
      const senderId = messageData.senderId;
      const receiverId = participants[0] === senderId ? participants[1] : participants[0];
      
      console.log('[FCM Function] Receiver ID:', receiverId);
      
      // Fetch receiver's user document to get FCM token
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();
      
      if (!receiverDoc.exists) {
        console.error('[FCM Function] ❌ Receiver document not found:', receiverId);
        return null;
      }
      
      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;
      
      if (!fcmToken) {
        console.log('[FCM Function] ⚠️ Receiver has no FCM token (app not installed or logged out)');
        return null;
      }
      
      console.log('[FCM Function] ✅ FCM token found:', fcmToken.substring(0, 20) + '...');
      
      // Fetch sender's name for notification
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      
      const senderName = senderDoc.exists ? (senderDoc.data().name || 'Someone') : 'Someone';
      
      console.log('[FCM Function] Sender name:', senderName);
      
      // Prepare notification payload
      const messageText = messageData.text || '🎤 Audio message';
      const notificationTitle = `New Message from ${senderName}`;
      const notificationBody = messageText.length > 100 
        ? messageText.substring(0, 100) + '...' 
        : messageText;
      
      const payload = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
          sound: 'default',
        },
        data: {
          chatId: chatId,
          senderId: senderId,
          messageId: messageId,
          type: 'chat_message',
        },
        token: fcmToken,
      };
      
      console.log('[FCM Function] 📤 Sending notification...');
      console.log('[FCM Function] Title:', notificationTitle);
      console.log('[FCM Function] Body:', notificationBody);
      
      // Send notification
      const response = await admin.messaging().send(payload);
      
      console.log('[FCM Function] ✅ Notification sent successfully!');
      console.log('[FCM Function] Response:', response);
      console.log('═══════════════════════════════════════');
      
      return response;
      
    } catch (error) {
      console.error('═══════════════════════════════════════');
      console.error('[FCM Function] ❌ Error sending notification:', error);
      console.error('[FCM Function] Error details:', error.message);
      console.error('[FCM Function] Stack trace:', error.stack);
      console.error('═══════════════════════════════════════');
      
      // Don't throw error to prevent function retry
      return null;
    }
  });

/**
 * Optional: Clean up FCM token on user deletion
 */
exports.cleanupUserData = functions.firestore
  .document('users/{userId}')
  .onDelete(async (snapshot, context) => {
    const userId = context.params.userId;
    console.log('[FCM Function] 🗑️ User deleted, cleaning up:', userId);
    
    // Additional cleanup logic can be added here
    return null;
  });
