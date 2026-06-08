const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

function loadLocalEnv(envPath) {
  if (!fs.existsSync(envPath)) {
    return;
  }

  const content = fs.readFileSync(envPath, 'utf8');
  const lines = content.split(/\r?\n/);

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (!line || line.startsWith('#')) {
      continue;
    }

    const separatorIndex = line.indexOf('=');
    if (separatorIndex === -1) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (key && !process.env[key]) {
      process.env[key] = value;
    }
  }
}

loadLocalEnv(path.join(__dirname, '.env'));

admin.initializeApp();

const { createGroqCompletion, validateGroqConfig } = require('./groqService');

const logger = functions.logger;
const db = admin.firestore();

const RATE_LIMIT_WINDOW_MS = Number(process.env.GROQ_RATE_LIMIT_WINDOW_MS || 60000);
const RATE_LIMIT_MAX_REQUESTS = Number(process.env.GROQ_RATE_LIMIT_MAX_REQUESTS || 8);
const RATE_LIMIT_SWEEP_MS = Number(process.env.GROQ_RATE_LIMIT_SWEEP_MS || 10 * 60 * 1000);
const AI_MAX_MESSAGES = Number(process.env.GROQ_MAX_HISTORY_MESSAGES || 16);
const AI_MAX_MESSAGE_LENGTH = Number(process.env.GROQ_MAX_MESSAGE_LENGTH || 4000);

function normalizeStatus(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, '_');
}

function buildRankScore({
  averageRating = 0,
  totalReviews = 0,
  completedJobs = 0,
  reviewQualityScore = 0,
}) {
  const ratingWeight = averageRating * 100;
  const trustWeight = Math.min(totalReviews, 50) * 2;
  const volumeWeight = Math.min(completedJobs, 100);
  const qualityWeight = reviewQualityScore * 10;
  return Number((ratingWeight + trustWeight + volumeWeight + qualityWeight).toFixed(3));
}

async function updateTechnicianSummary(technicianId, stats) {
  const averageRating = Number(stats.averageRating || 0);
  const totalReviews = Number(stats.totalReviews || 0);
  const completedJobs = Number(stats.completedJobs || 0);
  const rankScore = buildRankScore({
    averageRating,
    totalReviews,
    completedJobs,
    reviewQualityScore: Number(stats.reviewQualityScore || 0),
  });

  await Promise.all([
    db.collection('technician_stats').doc(technicianId).set({
      ...stats,
      averageRating,
      totalReviews,
      completedJobs,
      rankScore,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
    db.collection('users').doc(technicianId).set({
      rating: averageRating,
      averageRating,
      reviewCount: totalReviews,
      jobsCompleted: completedJobs,
      rankScore,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);
}

async function incrementCompletedJobs(technicianId) {
  if (!technicianId) return;

  const statsRef = db.collection('technician_stats').doc(technicianId);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(statsRef);
    const data = snap.exists ? snap.data() : {};
    const completedJobs = Number(data.completedJobs || 0) + 1;
    const averageRating = Number(data.averageRating || 0);
    const totalReviews = Number(data.totalReviews || 0);
    const reviewQualityScore = Number(data.reviewQualityScore || 0);
    const rankScore = buildRankScore({
      averageRating,
      totalReviews,
      completedJobs,
      reviewQualityScore,
    });

    transaction.set(statsRef, {
      technicianId,
      completedJobs,
      averageRating,
      totalReviews,
      ratingSum: Number(data.ratingSum || 0),
      reviewQualityScore,
      rankScore,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(db.collection('users').doc(technicianId), {
      jobsCompleted: completedJobs,
      rating: averageRating,
      averageRating,
      reviewCount: totalReviews,
      rankScore,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

const aiRequestCounts = new Map();
let lastRateLimitSweep = Date.now();

function sweepRateLimiter(now = Date.now()) {
  if (now - lastRateLimitSweep < RATE_LIMIT_SWEEP_MS) {
    return;
  }

  for (const [key, entry] of aiRequestCounts.entries()) {
    if (now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
      aiRequestCounts.delete(key);
    }
  }

  lastRateLimitSweep = now;
}

function getClientIp(req) {
  const forwarded = req.get('x-forwarded-for');
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }

  return (
    req.get('x-real-ip') ||
    req.ip ||
    req.socket?.remoteAddress ||
    'unknown'
  );
}

function rateLimitAiRequest({ userId, ip, requestId }) {
  const now = Date.now();
  sweepRateLimiter(now);

  const key = `${userId || 'anonymous'}:${ip || 'unknown'}`;
  const current = aiRequestCounts.get(key);

  if (!current || now - current.windowStart >= RATE_LIMIT_WINDOW_MS) {
    aiRequestCounts.set(key, { windowStart: now, count: 1 });
    return;
  }

  if (current.count >= RATE_LIMIT_MAX_REQUESTS) {
    const error = new Error('Too many AI requests. Please wait a moment and try again.');
    error.statusCode = 429;
    error.code = 'rate_limited';

    logger.warn('AI rate limit exceeded', {
      requestId,
      userId,
      ip,
      count: current.count,
      windowMs: RATE_LIMIT_WINDOW_MS,
    });

    throw error;
  }

  current.count += 1;
  aiRequestCounts.set(key, current);
}

function validateGroqMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0) {
    const error = new Error('messages is required.');
    error.statusCode = 400;
    error.code = 'invalid_messages';
    throw error;
  }

  if (messages.length > AI_MAX_MESSAGES) {
    const error = new Error(`Too many messages. Maximum allowed is ${AI_MAX_MESSAGES}.`);
    error.statusCode = 400;
    error.code = 'too_many_messages';
    throw error;
  }

  for (const [index, message] of messages.entries()) {
    if (!message || typeof message !== 'object') {
      const error = new Error(`Message at index ${index} is invalid.`);
      error.statusCode = 400;
      error.code = 'invalid_message';
      throw error;
    }

    const role = message.role;
    const content = message.content;
    if (!['system', 'user', 'assistant'].includes(role)) {
      const error = new Error(`Message role at index ${index} is invalid.`);
      error.statusCode = 400;
      error.code = 'invalid_message_role';
      throw error;
    }

    if (typeof content !== 'string' || !content.trim()) {
      const error = new Error(`Message content at index ${index} is missing.`);
      error.statusCode = 400;
      error.code = 'invalid_message_content';
      throw error;
    }

    if (content.length > AI_MAX_MESSAGE_LENGTH) {
      const error = new Error(`Message at index ${index} is too long.`);
      error.statusCode = 400;
      error.code = 'message_too_long';
      throw error;
    }
  }
}

function sanitizeAiError(error) {
  const statusCode = error.statusCode || error.status || 500;
  const isAuth = statusCode === 401;
  const isRateLimit = statusCode === 429;

  return {
    statusCode,
    code: error.code || 'ai_error',
    message: isAuth
      ? 'Please sign in again to continue.'
      : isRateLimit
        ? 'You are sending requests too quickly. Please wait a moment and try again.'
        : statusCode >= 500
          ? 'The AI service is temporarily unavailable. Please try again in a moment.'
          : error.message || 'Request failed.',
  };
}

function setCorsHeaders(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Max-Age', '3600');
}

function getBearerToken(req) {
  const header = req.get('Authorization') || req.get('authorization') || '';

  if (!header.startsWith('Bearer ')) {
    return '';
  }

  return header.slice(7).trim();
}

function readRequestBody(req) {
  if (req.body && typeof req.body === 'object') {
    return req.body;
  }

  if (typeof req.body === 'string' && req.body.trim()) {
    try {
      return JSON.parse(req.body);
    } catch (error) {
      return {};
    }
  }

  return {};
}

async function verifyRequest(req) {
  const token = getBearerToken(req);

  if (!token) {
    const error = new Error('Missing authorization token.');
    error.statusCode = 401;
    throw error;
  }

  return admin.auth().verifyIdToken(token);
}

function sendJsonError(res, error) {
  const normalized = sanitizeAiError(error);

  res.status(normalized.statusCode).json({
    error: normalized.message,
  });
}

function writeSseEvent(res, eventName, data) {
  if (res.writableEnded || res.destroyed) {
    return;
  }

  res.write(`event: ${eventName}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

async function handleGroqRequest(req, res, stream) {
  setCorsHeaders(res);
  const requestId = req.get('x-request-id') || randomUUID();
  const ip = getClientIp(req);
  const startTime = Date.now();
  const abortController = new AbortController();
  let clientClosed = false;

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed.' });
    return;
  }

  try {
    const decodedToken = await verifyRequest(req);
    validateGroqConfig();
    const body = readRequestBody(req);
    const { messages } = body;

    validateGroqMessages(messages);
    rateLimitAiRequest({
      userId: decodedToken.uid,
      ip,
      requestId,
    });

    logger.info('AI request received', {
      requestId,
      userId: decodedToken.uid,
      ip,
      stream,
      messageCount: messages.length,
    });

    const closeHandler = () => {
      if (res.writableEnded) {
        return;
      }

      clientClosed = true;
      abortController.abort();
      logger.info('AI request connection closed by client', {
        requestId,
        userId: decodedToken.uid,
        stream,
      });
    };

    req.on('close', closeHandler);

    if (stream) {
      res.status(200);
      res.set('Content-Type', 'text/event-stream; charset=utf-8');
      res.set('Cache-Control', 'no-cache, no-transform');
      res.set('Connection', 'keep-alive');
      res.set('X-Accel-Buffering', 'no');
      if (typeof res.flushHeaders === 'function') {
        res.flushHeaders();
      }

      writeSseEvent(res, 'ready', { ok: true });

      const result = await createGroqCompletion({
        messages,
        userId: decodedToken.uid,
        requestId,
        stream: true,
        onDelta: (reply) => {
          if (clientClosed) {
            return;
          }
          writeSseEvent(res, 'delta', { reply });
        },
        signal: abortController.signal,
      });

      if (clientClosed) {
        return;
      }

      writeSseEvent(res, 'final', result);
      writeSseEvent(res, 'done', { ok: true });
      logger.info('AI stream response sent', {
        requestId,
        userId: decodedToken.uid,
        durationMs: Date.now() - startTime,
        model: result.model,
        usage: result.usage || null,
      });
      res.end();
      return;
    }

    const result = await createGroqCompletion({
      messages,
      userId: decodedToken.uid,
      requestId,
      stream: false,
      signal: abortController.signal,
    });

    logger.info('AI response sent', {
      requestId,
      userId: decodedToken.uid,
      durationMs: Date.now() - startTime,
      model: result.model,
      usage: result.usage || null,
    });

    res.status(200).json(result);
  } catch (error) {
    const normalized = sanitizeAiError(error);

    logger.error('AI request failed', {
      requestId,
      ip,
      stream,
      durationMs: Date.now() - startTime,
      statusCode: normalized.statusCode,
      code: normalized.code,
      message: error.message,
    });

    if (stream) {
      writeSseEvent(res, 'error', {
        error: normalized.message,
      });
      if (!clientClosed) {
        res.end();
      }
      return;
    }

    sendJsonError(res, error);
  } finally {
    req.removeAllListeners('close');
    if (!res.writableEnded && !clientClosed && !stream) {
      abortController.abort();
    }
  }
}

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
      console.log('=================================================');
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
      const receiverId =
        participants[0] === senderId ? participants[1] : participants[0];

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

      const senderName = senderDoc.exists
        ? (senderDoc.data().name || 'Someone')
        : 'Someone';

      console.log('[FCM Function] Sender name:', senderName);

      // Prepare notification payload
      const messageText = messageData.text || '🎤 Audio message';
      const notificationTitle = `New Message from ${senderName}`;
      const notificationBody =
        messageText.length > 100
          ? `${messageText.substring(0, 100)}...`
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
      console.log('=================================================');

      return response;
    } catch (error) {
      console.error('=================================================');
      console.error('[FCM Function] ❌ Error sending notification:', error);
      console.error('[FCM Function] Error details:', error.message);
      console.error('[FCM Function] Stack trace:', error.stack);
      console.error('=================================================');

      // Don't throw error to prevent function retry
      return null;
    }
  });

/**
 * Cloud Function: Send FCM push notification when a notification doc is created
 * Trigger: notifications/{notificationId} onCreate
 * Covers: booking_request, booking_accepted, booking_rejected,
 *         technician_on_way, job_started, job_completed, booking_submitted
 */
exports.sendBookingNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    try {
      const data = snapshot.data();
      const { recipientId, title, body, type, bookingId, chatId } = data;

      if (!recipientId || !title || !body) {
        console.log('[BookingNotif] Missing required fields, skipping.');
        return null;
      }

      const recipientDoc = await admin.firestore()
        .collection('users').doc(recipientId).get();

      if (!recipientDoc.exists) {
        console.log('[BookingNotif] Recipient not found:', recipientId);
        return null;
      }

      const fcmToken = recipientDoc.data().fcmToken;
      if (!fcmToken) {
        console.log('[BookingNotif] No FCM token for recipient:', recipientId);
        return null;
      }

      const payload = {
        notification: { title, body, sound: 'default' },
        data: {
          type: type || 'notification',
          bookingId: bookingId || '',
          chatId: chatId || '',
        },
        token: fcmToken,
      };

      const response = await admin.messaging().send(payload);
      console.log('[BookingNotif] ✅ Sent:', type, '→', recipientId, '|', response);
      return response;
    } catch (error) {
      console.error('[BookingNotif] ❌ Error:', error.message);
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
    return null;
  });

exports.groqChat = functions.https.onRequest(async (req, res) => {
  await handleGroqRequest(req, res, false);
});

exports.groqChatStream = functions.https.onRequest(async (req, res) => {
  await handleGroqRequest(req, res, true);
});

/**
 * Cloud Function: Aggregate technician stats when a review is created
 * Trigger: reviews/{reviewId} onCreate
 * 
 * Automatically calculates:
 * - averageRating (sum of ratings / total reviews)
 * - totalReviews count
 * - reviewQualityScore (weighted by comment quality)
 * - rankScore (composite score for marketplace ranking)
 */
exports.aggregateTechnicianReview = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snapshot, context) => {
    try {
      const reviewData = snapshot.data();
      const { technicianId, rating, comment } = reviewData;

      if (!technicianId) {
        console.log('[ReviewAggregation] Missing technicianId, skipping.');
        return null;
      }

      console.log('[ReviewAggregation] 🌟 Processing review for technician:', technicianId);

      // Fetch all reviews for this technician
      const reviewsSnapshot = await db.collection('reviews')
        .where('technicianId', '==', technicianId)
        .get();

      let ratingSum = 0;
      let totalReviews = 0;
      let qualityScoreSum = 0;

      for (const doc of reviewsSnapshot.docs) {
        const data = doc.data();
        const reviewRating = Number(data.rating || 0);
        const reviewComment = String(data.comment || '').trim();
        
        ratingSum += reviewRating;
        totalReviews += 1;
        
        // Quality bonus: longer meaningful comments = better quality
        const commentBonus = reviewComment.length >= 12 ? 0.2 : 0.0;
        qualityScoreSum += (reviewRating / 5.0) + commentBonus;
      }

      const averageRating = totalReviews > 0 
        ? Number((ratingSum / totalReviews).toFixed(2)) 
        : 0;
      
      const reviewQualityScore = totalReviews > 0
        ? Number((qualityScoreSum / totalReviews).toFixed(2))
        : 0;

      // Get completed jobs count
      const statsRef = db.collection('technician_stats').doc(technicianId);
      const statsSnap = await statsRef.get();
      const currentStats = statsSnap.exists ? statsSnap.data() : {};
      const completedJobs = Number(currentStats.completedJobs || 0);

      // Update stats document and user profile
      await updateTechnicianSummary(technicianId, {
        technicianId,
        averageRating,
        totalReviews,
        completedJobs,
        ratingSum,
        reviewQualityScore,
      });

      console.log('[ReviewAggregation] ✅ Updated stats for technician:', technicianId);
      console.log('[ReviewAggregation] Average Rating:', averageRating);
      console.log('[ReviewAggregation] Total Reviews:', totalReviews);
      console.log('[ReviewAggregation] Completed Jobs:', completedJobs);
      console.log('[ReviewAggregation] Rank Score:', buildRankScore({
        averageRating,
        totalReviews,
        completedJobs,
        reviewQualityScore,
      }));

      return null;
    } catch (error) {
      console.error('[ReviewAggregation] ❌ Error:', error.message);
      return null;
    }
  });

/**
 * Cloud Function: Increment completed jobs count when booking status becomes 'completed'
 * Trigger: bookings/{bookingId} onUpdate
 */
exports.updateCompletedJobsCount = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      const oldStatus = normalizeStatus(before.status || '');
      const newStatus = normalizeStatus(after.status || '');

      // Only trigger when status changes TO 'completed'
      if (oldStatus !== 'completed' && newStatus === 'completed') {
        const technicianId = after.technicianId;
        
        if (!technicianId) {
          console.log('[CompletedJobs] Missing technicianId, skipping.');
          return null;
        }

        console.log('[CompletedJobs] 🎉 Job completed for technician:', technicianId);
        await incrementCompletedJobs(technicianId);
        console.log('[CompletedJobs] ✅ Incremented completed jobs count');
      }

      return null;
    } catch (error) {
      console.error('[CompletedJobs] ❌ Error:', error.message);
      return null;
    }
  });
