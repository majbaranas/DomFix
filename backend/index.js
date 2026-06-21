const express = require('express');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const cors = require('cors');

console.log('═══════════════════════════════════════');
console.log('[DomFix Backend] Loading service account...');

// Initialize Firebase Admin SDK
let serviceAccount;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log('[DomFix Backend] ✅ Loaded service account from environment variable');
  } else {
    // Fallback to a local file for development (do not commit this file to Git!)
    serviceAccount = require('./serviceAccountKey.json');
    console.log('[DomFix Backend] ✅ Loaded service account from serviceAccountKey.json');
  }
} catch (error) {
  console.error('[DomFix Backend] ❌ Failed to load Firebase Service Account credential.');
  console.error('[DomFix Backend] Make sure FIREBASE_SERVICE_ACCOUNT env var is set or serviceAccountKey.json exists.');
  console.error('[DomFix Backend] Error:', error.message);
  process.exit(1);
}

initializeApp({
  credential: cert(serviceAccount)
});
console.log('[DomFix Backend] ✅ Firebase Admin SDK initialized');

const db = getFirestore();
const app = express();

// Middleware
app.use(cors({ origin: true }));
app.use(express.json());

// ─── Health Check Endpoint ──────────────────────────────────
app.get('/', (req, res) => {
  res.status(200).send({
    status: 'running',
    service: 'DomFix Notification Backend',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// ─── Main Endpoint: Send Notification ───────────────────────
app.post('/api/notify', async (req, res) => {
  const requestId = Date.now().toString(36);
  console.log('═══════════════════════════════════════');
  console.log(`[${requestId}] 📬 POST /api/notify — Request received`);
  console.log(`[${requestId}] Body:`, JSON.stringify(req.body));

  try {
    const { receiverId, title, body, data } = req.body;

    // ── Step 1: Validate input ──
    if (!receiverId || !title || !body) {
      console.log(`[${requestId}] ❌ Validation failed: Missing required fields`);
      console.log(`[${requestId}]   receiverId: ${receiverId || 'MISSING'}`);
      console.log(`[${requestId}]   title: ${title || 'MISSING'}`);
      console.log(`[${requestId}]   body: ${body || 'MISSING'}`);
      return res.status(400).send({ error: 'Missing required fields: receiverId, title, body' });
    }
    console.log(`[${requestId}] ✅ Step 1: Input validated`);
    console.log(`[${requestId}]   receiverId: ${receiverId}`);
    console.log(`[${requestId}]   title: ${title}`);
    console.log(`[${requestId}]   body: ${body}`);

    // ── Step 2: Fetch user document from Firestore ──
    console.log(`[${requestId}] 🔍 Step 2: Fetching user document for ${receiverId}...`);
    const userDoc = await db.collection('users').doc(receiverId).get();

    if (!userDoc.exists) {
      console.log(`[${requestId}] ❌ Step 2 FAILED: Receiver not found in Firestore`);
      console.log(`[${requestId}]   Searched: users/${receiverId}`);
      return res.status(404).send({ error: 'Receiver not found in Firestore users collection' });
    }
    console.log(`[${requestId}] ✅ Step 2: User document found`);

    // ── Step 3: Extract FCM token ──
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`[${requestId}] ⚠️ Step 3: User ${receiverId} has no FCM token`);
      console.log(`[${requestId}]   User data keys: ${Object.keys(userData).join(', ')}`);
      return res.status(200).send({ success: false, message: 'User has no active FCM token' });
    }
    console.log(`[${requestId}] ✅ Step 3: FCM token found: ${fcmToken.substring(0, 20)}...`);

    // ── Step 4: Ensure all data values are strings (FCM requirement) ──
    const safeData = {};
    if (data && typeof data === 'object') {
      for (const [key, value] of Object.entries(data)) {
        safeData[key] = String(value);
      }
    }
    console.log(`[${requestId}] ✅ Step 4: Data payload sanitized:`, JSON.stringify(safeData));

    // ── Step 5: Construct FCM message ──
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: safeData,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          priority: 'high',
          defaultVibrateTimings: true,
          defaultSound: true,
          notificationCount: 1,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
      },
    };
    console.log(`[${requestId}] ✅ Step 5: FCM message constructed`);

    // ── Step 6: Send via Firebase Admin SDK ──
    console.log(`[${requestId}] 🚀 Step 6: Sending notification via FCM...`);
    const response = await getMessaging().send(message);
    console.log(`[${requestId}] ✅ Step 6: Notification sent successfully!`);
    console.log(`[${requestId}]   FCM Message ID: ${response}`);
    console.log('═══════════════════════════════════════');

    res.status(200).send({ success: true, messageId: response });
  } catch (error) {
    console.log(`[${requestId}] ❌ ERROR in notification pipeline`);
    console.log(`[${requestId}]   Error code: ${error.code || 'N/A'}`);
    console.log(`[${requestId}]   Error message: ${error.message}`);

    // Handle specific FCM errors
    if (error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token') {
      console.log(`[${requestId}] 🧹 Stale/invalid FCM token detected. Cleaning up...`);
      
      // Optionally remove the stale token from Firestore
      try {
        const { receiverId } = req.body;
        if (receiverId) {
          await db.collection('users').doc(receiverId).update({
            fcmToken: null,
            fcmTokenUpdatedAt: null,
          });
          console.log(`[${requestId}] ✅ Stale token removed from user ${receiverId}`);
        }
      } catch (cleanupError) {
        console.log(`[${requestId}] ⚠️ Failed to cleanup stale token: ${cleanupError.message}`);
      }
    }

    console.log('═══════════════════════════════════════');
    res.status(500).send({ error: error.message });
  }
});

// ─── Test Endpoint: Send test notification to a specific user ──
app.get('/api/test-notify/:userId', async (req, res) => {
  const userId = req.params.userId;
  console.log('═══════════════════════════════════════');
  console.log(`[TEST] Sending test notification to user: ${userId}`);

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return res.status(404).send({ error: `User ${userId} not found` });
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      return res.status(400).send({ error: `User ${userId} has no FCM token` });
    }

    const message = {
      token: fcmToken,
      notification: {
        title: '🔔 DomFix Test',
        body: 'If you see this, notifications are working!',
      },
      data: {
        type: 'test',
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    const response = await getMessaging().send(message);
    console.log(`[TEST] ✅ Test notification sent! Message ID: ${response}`);
    console.log('═══════════════════════════════════════');

    res.status(200).send({
      success: true,
      messageId: response,
      sentTo: userId,
      tokenPrefix: fcmToken.substring(0, 20) + '...',
    });
  } catch (error) {
    console.log(`[TEST] ❌ Error: ${error.message}`);
    console.log('═══════════════════════════════════════');
    res.status(500).send({ error: error.message });
  }
});

// ─── Debug Endpoint: Check user's FCM token ────────────────
app.get('/api/check-token/:userId', async (req, res) => {
  const userId = req.params.userId;
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).send({ error: `User ${userId} not found` });
    }
    const data = userDoc.data();
    res.status(200).send({
      userId: userId,
      hasFcmToken: !!data.fcmToken,
      tokenPrefix: data.fcmToken ? data.fcmToken.substring(0, 30) + '...' : null,
      fcmTokenUpdatedAt: data.fcmTokenUpdatedAt || null,
      role: data.role || null,
      name: data.name || null,
    });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log('═══════════════════════════════════════');
  console.log(`DomFix Notification Backend running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/`);
  console.log(`Notify endpoint: POST http://localhost:${PORT}/api/notify`);
  console.log(`Test endpoint: GET http://localhost:${PORT}/api/test-notify/:userId`);
  console.log(`Token check: GET http://localhost:${PORT}/api/check-token/:userId`);
  console.log('═══════════════════════════════════════');
});
