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

// ═══════════════════════════════════════════════════════════════
// ─── AI PROXY ENDPOINTS ────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════

const https = require('https');
const { getAuth } = require('firebase-admin/auth');

// ── Rate Limiter (in-memory, per-user) ─────────────────────────
const aiRateLimits = new Map();
const AI_RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const AI_RATE_LIMIT_MAX = 20; // 20 requests per minute

function checkAiRateLimit(uid) {
  const now = Date.now();
  let entry = aiRateLimits.get(uid);
  if (!entry || now - entry.windowStart > AI_RATE_LIMIT_WINDOW_MS) {
    entry = { windowStart: now, count: 0 };
    aiRateLimits.set(uid, entry);
  }
  entry.count += 1;
  return entry.count <= AI_RATE_LIMIT_MAX;
}

// Clean up stale entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [uid, entry] of aiRateLimits) {
    if (now - entry.windowStart > AI_RATE_LIMIT_WINDOW_MS * 2) {
      aiRateLimits.delete(uid);
    }
  }
}, 300_000);

// ── Firebase Auth Middleware ──────────────────────────────────
async function verifyFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header.' });
  }
  const idToken = authHeader.substring(7);
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.log(`[AI] ❌ Auth failed: ${err.message}`);
    return res.status(401).json({ error: 'Invalid or expired authentication token.' });
  }
}

// ── DomFix System Prompt ──────────────────────────────────────
const DOMFIX_SYSTEM_PROMPT = `You are DomFix AI, a friendly and knowledgeable home repair and maintenance assistant. You help users with:
- Diagnosing household problems (plumbing, electrical, HVAC, appliances)
- Finding the right type of technician for their issue
- Providing step-by-step DIY repair guides when safe
- Estimating repair costs and timelines
- Smart home device troubleshooting
- Energy efficiency and maintenance tips

Guidelines:
- Be concise but thorough
- Always prioritize safety — recommend a professional for electrical, gas, or structural work
- When suggesting a fix, mention required tools and skill level
- Use clear formatting with steps when explaining procedures
- If you're unsure, say so and recommend consulting a licensed professional
- Respond in the same language the user writes in`;

const GROQ_API_HOST = 'api.groq.com';
const GROQ_API_PATH = '/openai/v1/chat/completions';
const GROQ_MODEL = 'llama3-70b-8192';

// ── Input Sanitization ────────────────────────────────────────
function sanitizeMessages(messages) {
  if (!Array.isArray(messages)) return [];
  return messages
    .filter(m => m && typeof m.role === 'string' && typeof m.content === 'string')
    .map(m => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content.substring(0, 4000), // Cap message length
    }))
    .slice(-20); // Keep last 20 messages max
}

// ── Helper: call Groq (JSON mode) ─────────────────────────────
function callGroqJson(messages, retryCount = 0) {
  return new Promise((resolve, reject) => {
    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      return reject(new Error('GROQ_API_KEY environment variable is not set.'));
    }

    const model = retryCount > 0 ? 'llama-3.1-8b-instant' : GROQ_MODEL;
    const body = JSON.stringify({
      model: model,
      messages: messages,
      stream: false,
      temperature: 0.7,
      max_tokens: 2048,
    });

    const options = {
      hostname: GROQ_API_HOST,
      path: GROQ_API_PATH,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqKey}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      timeout: 30000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error('Invalid JSON response from AI provider.'));
          }
        } else {
          let errMsg = data;
          try { errMsg = JSON.parse(data).error?.message || data; } catch {}
          
          if (retryCount < 2) {
             console.log(`[Groq JSON] Retry ${retryCount + 1} after error: ${errMsg}`);
             resolve(callGroqJson(messages, retryCount + 1));
          } else {
             const err = new Error(`Groq API error: ${errMsg}`);
             err.statusCode = res.statusCode;
             reject(err);
          }
        }
      });
    });

    req.on('timeout', () => { 
      req.destroy(); 
      if (retryCount < 2) resolve(callGroqJson(messages, retryCount + 1));
      else reject(new Error('AI provider request timed out.'));
    });
    req.on('error', (e) => {
      if (retryCount < 2) resolve(callGroqJson(messages, retryCount + 1));
      else reject(new Error(`AI provider connection failed: ${e.message}`));
    });
    req.write(body);
    req.end();
  });
}

// ── POST /api/ai/chat — JSON response ─────────────────────────
app.post('/api/ai/chat', verifyFirebaseToken, async (req, res) => {
  const requestId = Date.now().toString(36);
  console.log(`[${requestId}] 🤖 POST /api/ai/chat — uid: ${req.uid}`);

  // Rate limit
  if (!checkAiRateLimit(req.uid)) {
    console.log(`[${requestId}] ⚠️ Rate limited: ${req.uid}`);
    return res.status(429).json({ error: 'Too many requests. Please wait a moment.' });
  }

  try {
    const userMessages = sanitizeMessages(req.body.messages);
    if (userMessages.length === 0) {
      return res.status(400).json({ error: 'No valid messages provided.' });
    }

    const fullMessages = [
      { role: 'system', content: DOMFIX_SYSTEM_PROMPT },
      ...userMessages,
    ];

    const groqResponse = await callGroqJson(fullMessages);

    const choices = groqResponse.choices || [];
    const content = choices[0]?.message?.content || '';

    const result = {
      reply: content.trim(),
      proTip: '',
      specialist: 'DomFix AI',
      model: groqResponse.model || GROQ_MODEL,
      usage: groqResponse.usage || null,
    };

    console.log(`[${requestId}] ✅ AI response: ${result.reply.substring(0, 80)}...`);
    res.status(200).json(result);
  } catch (err) {
    console.error(`[${requestId}] ❌ AI chat error: ${err.message}`);
    const status = err.statusCode === 429 ? 429 : (err.statusCode >= 400 && err.statusCode < 500) ? err.statusCode : 500;
    res.status(status).json({ error: err.message || 'The AI service is temporarily unavailable.' });
  }
});

// ── POST /api/ai/chat/stream — SSE streaming ──────────────────
app.post('/api/ai/chat/stream', verifyFirebaseToken, async (req, res) => {
  const requestId = Date.now().toString(36);
  console.log(`[${requestId}] 🤖 POST /api/ai/chat/stream — uid: ${req.uid}`);

  if (!checkAiRateLimit(req.uid)) {
    console.log(`[${requestId}] ⚠️ Rate limited: ${req.uid}`);
    return res.status(429).json({ error: 'Too many requests. Please wait a moment.' });
  }

  const groqKey = process.env.GROQ_API_KEY;
  if (!groqKey) {
    console.error(`[${requestId}] ❌ GROQ_API_KEY not set`);
    return res.status(500).json({ error: 'AI service is not configured.' });
  }

  const userMessages = sanitizeMessages(req.body.messages);
  if (userMessages.length === 0) {
    return res.status(400).json({ error: 'No valid messages provided.' });
  }

  const fullMessages = [
    { role: 'system', content: DOMFIX_SYSTEM_PROMPT },
    ...userMessages,
  ];

  function attemptStream(retryCount = 0) {
    const model = retryCount > 0 ? 'llama-3.1-8b-instant' : GROQ_MODEL;
    const body = JSON.stringify({
      model: model,
      messages: fullMessages,
      stream: true,
      temperature: 0.7,
      max_tokens: 2048,
    });

    const options = {
      hostname: GROQ_API_HOST,
      path: GROQ_API_PATH,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqKey}`,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      timeout: 30000,
    };

    let headersWritten = false;
    let fullReply = '';
    let groqModel = model;
    let groqUsage = null;

    const groqReq = https.request(options, (groqRes) => {
      if (groqRes.statusCode >= 300) {
        let errBody = '';
        groqRes.on('data', c => errBody += c);
        groqRes.on('end', () => {
          let errMsg = errBody;
          try { errMsg = JSON.parse(errBody).error?.message || errBody; } catch {}
          console.error(`[${requestId}] ❌ Groq stream error ${groqRes.statusCode}: ${errMsg}`);
          
          if (retryCount < 2) {
            console.log(`[${requestId}] 🔄 Retrying stream (attempt ${retryCount + 1})...`);
            attemptStream(retryCount + 1);
          } else {
             if (!headersWritten) {
               res.status(groqRes.statusCode).json({ error: errMsg });
             } else {
               res.write(`data: ${JSON.stringify({ error: errMsg })}\n\n`);
               res.end();
             }
          }
        });
        return;
      }

      // Success, write SSE headers if not already written
      if (!headersWritten) {
        res.writeHead(200, {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'X-Accel-Buffering': 'no',
        });
        headersWritten = true;
      }

      let buffer = '';
      groqRes.on('data', (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop() || ''; // Keep incomplete line in buffer

        for (const line of lines) {
          if (!line.startsWith('data:')) continue;
          const data = line.substring(5).trim();
          if (data === '[DONE]') continue;
          if (!data) continue;

          try {
            const parsed = JSON.parse(data);
            const delta = parsed.choices?.[0]?.delta;
            if (delta?.content) {
              fullReply += delta.content;
              // Forward partial reply in DomFix format
              res.write(`data: ${JSON.stringify({ reply: fullReply })}\n\n`);
            }
            if (parsed.model) groqModel = parsed.model;
            if (parsed.usage) groqUsage = parsed.usage;
          } catch (_) {
            // Ignore malformed chunks
          }
        }
      });

      groqRes.on('end', () => {
        // Send final metadata chunk
        const finalChunk = {
          reply: fullReply.trim(),
          proTip: '',
          specialist: 'DomFix AI',
          model: groqModel,
          usage: groqUsage,
        };
        res.write(`data: ${JSON.stringify(finalChunk)}\n\n`);
        res.write('data: [DONE]\n\n');
        res.end();
        console.log(`[${requestId}] ✅ Stream complete: ${fullReply.substring(0, 80)}...`);
      });

      groqRes.on('error', (e) => {
        console.error(`[${requestId}] ❌ Groq stream read error: ${e.message}`);
        res.write(`data: ${JSON.stringify({ error: 'Stream interrupted.' })}\n\n`);
        res.end();
      });
    });

    groqReq.on('timeout', () => {
      groqReq.destroy();
      console.error(`[${requestId}] ❌ Groq stream timeout`);
      if (retryCount < 2 && !headersWritten) {
        attemptStream(retryCount + 1);
      } else {
        if (!headersWritten) res.status(504).json({ error: 'AI provider timed out.' });
        else {
          res.write(`data: ${JSON.stringify({ error: 'AI provider timed out.' })}\n\n`);
          res.end();
        }
      }
    });

    groqReq.on('error', (e) => {
      console.error(`[${requestId}] ❌ Groq stream connection error: ${e.message}`);
      if (retryCount < 2 && !headersWritten) {
        attemptStream(retryCount + 1);
      } else {
        if (!headersWritten) res.status(502).json({ error: 'AI provider connection failed.' });
        else if (!res.writableEnded) {
          res.write(`data: ${JSON.stringify({ error: 'AI provider connection failed.' })}\n\n`);
          res.end();
        }
      }
    });

    // Cleanup if client disconnects
    res.on('close', () => {
      groqReq.destroy();
    });

    groqReq.write(body);
    groqReq.end();
  }

  attemptStream(0);
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log('═══════════════════════════════════════');
  console.log(`DomFix Backend running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/`);
  console.log(`Notify endpoint: POST http://localhost:${PORT}/api/notify`);
  console.log(`AI chat:    POST http://localhost:${PORT}/api/ai/chat`);
  console.log(`AI stream:  POST http://localhost:${PORT}/api/ai/chat/stream`);
  console.log(`Test notify: GET http://localhost:${PORT}/api/test-notify/:userId`);
  console.log(`Token check: GET http://localhost:${PORT}/api/check-token/:userId`);
  console.log(`GROQ_API_KEY: ${process.env.GROQ_API_KEY ? '✅ Set' : '❌ NOT SET'}`);
  console.log('═══════════════════════════════════════');
});
