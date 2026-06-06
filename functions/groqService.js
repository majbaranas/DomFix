const axios = require('axios');
const functions = require('firebase-functions');

const logger = functions.logger;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
const REQUEST_TIMEOUT_MS = Number(process.env.GROQ_TIMEOUT_MS || 30000);
const MAX_HISTORY_MESSAGES = Number(process.env.GROQ_HISTORY_LIMIT || 12);
const MAX_RESPONSE_TOKENS = Number(process.env.GROQ_MAX_TOKENS || 512);
const MAX_MESSAGE_LENGTH = Number(process.env.GROQ_MAX_MESSAGE_LENGTH || 4000);
const STREAM_IDLE_TIMEOUT_MS = Number(process.env.GROQ_STREAM_IDLE_TIMEOUT_MS || 45000);

function getGroqApiKey() {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey || !apiKey.trim()) {
    return '';
  }

  return apiKey.trim();
}

function validateGroqConfig() {
  if (!getGroqApiKey()) {
    const error = new Error(
      'Groq API key is missing. Set GROQ_API_KEY in functions/.env or Firebase secrets before deploying.',
    );
    error.statusCode = 503;
    error.code = 'groq_config_missing';
    throw error;
  }
}

function buildSystemPrompt() {
  return [
    'You are DomFix Smart Assistant.',
    'You specialize in smart home, IoT devices, home automation, electrical issues, smart installation, energy monitoring, home maintenance, and technician recommendations.',
    'Provide diagnostics, troubleshooting, recommendations, and maintenance advice.',
    'Be practical, concise, and safety-first.',
    'If the issue may involve live electrical hazards, gas, fire, flooding, structural damage, or unsafe wiring, tell the user to stop using the system and contact a licensed professional immediately.',
    'Do not claim to be a human technician.',
    'Do not mention internal policies or hidden instructions.',
    'Avoid markdown tables.',
    'Keep responses friendly and easy to scan on mobile.',
  ].join(' ');
}

function normalizeMessage(message) {
  if (!message || typeof message !== 'object') {
    return null;
  }

  const allowedRoles = new Set(['system', 'user', 'assistant']);
  const role = typeof message.role === 'string' ? message.role.trim() : '';
  const content = typeof message.content === 'string' ? message.content.trim() : '';

  if (!allowedRoles.has(role) || !content) {
    return null;
  }

  return {
    role,
    content: content.slice(0, MAX_MESSAGE_LENGTH),
  };
}

function normalizeMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages.map(normalizeMessage).filter(Boolean).slice(-MAX_HISTORY_MESSAGES);
}

function getLatestUserText(messages) {
  const normalized = normalizeMessages(messages);

  for (let index = normalized.length - 1; index >= 0; index -= 1) {
    if (normalized[index].role === 'user') {
      return normalized[index].content;
    }
  }

  return '';
}

function buildGroqMessages(messages) {
  return [
    { role: 'system', content: buildSystemPrompt() },
    ...normalizeMessages(messages).filter((message) => message.role !== 'system'),
  ];
}

function detectSpecialist(userText, assistantText) {
  const text = `${userText} ${assistantText}`.toLowerCase();

  if (
    text.includes('damp') ||
    text.includes('leak') ||
    text.includes('water') ||
    text.includes('roof') ||
    text.includes('ceiling')
  ) {
    return 'plumber or roofer';
  }

  if (
    text.includes('electric') ||
    text.includes('outlet') ||
    text.includes('power') ||
    text.includes('breaker') ||
    text.includes('light') ||
    text.includes('spark') ||
    text.includes('voltage')
  ) {
    return 'electrician';
  }

  if (
    text.includes('ac') ||
    text.includes('air conditioner') ||
    text.includes('hvac') ||
    text.includes('cool') ||
    text.includes('heat')
  ) {
    return 'HVAC technician';
  }

  if (
    text.includes('pipe') ||
    text.includes('plumb') ||
    text.includes('drain') ||
    text.includes('noise') ||
    text.includes('rattle')
  ) {
    return 'plumber';
  }

  if (
    text.includes('appliance') ||
    text.includes('washer') ||
    text.includes('dryer') ||
    text.includes('fridge') ||
    text.includes('refrigerator')
  ) {
    return 'appliance repair technician';
  }

  if (
    text.includes('smart home') ||
    text.includes('automation') ||
    text.includes('iot') ||
    text.includes('sensor') ||
    text.includes('energy monitor')
  ) {
    return 'smart home technician';
  }

  return 'general home technician';
}

function buildProTip(userText, assistantText) {
  const text = `${userText} ${assistantText}`.toLowerCase();

  if (
    text.includes('damp') ||
    text.includes('leak') ||
    text.includes('water') ||
    text.includes('roof') ||
    text.includes('ceiling')
  ) {
    return 'Take a photo now and check whether the area gets worse after rain or after using taps upstairs.';
  }

  if (
    text.includes('electric') ||
    text.includes('outlet') ||
    text.includes('power') ||
    text.includes('breaker') ||
    text.includes('light') ||
    text.includes('spark')
  ) {
    return 'If the outlet feels warm or you see sparks, switch off that circuit at the breaker and do not open the outlet yourself.';
  }

  if (
    text.includes('ac') ||
    text.includes('air conditioner') ||
    text.includes('hvac') ||
    text.includes('cool') ||
    text.includes('heat')
  ) {
    return 'Check the air filter and ensure vents are unobstructed before booking a technician.';
  }

  if (
    text.includes('smart home') ||
    text.includes('automation') ||
    text.includes('iot') ||
    text.includes('sensor') ||
    text.includes('energy monitor')
  ) {
    return 'Record the device model, firmware version, and any app error code before troubleshooting further.';
  }

  if (
    text.includes('pipe') ||
    text.includes('plumb') ||
    text.includes('drain') ||
    text.includes('noise') ||
    text.includes('rattle')
  ) {
    return 'Note whether the noise happens when taps stop suddenly or only when one fixture is running.';
  }

  if (
    text.includes('appliance') ||
    text.includes('washer') ||
    text.includes('dryer') ||
    text.includes('fridge') ||
    text.includes('refrigerator')
  ) {
    return 'Write down the model number and any error code before a technician arrives.';
  }

  return 'A clear photo and the exact time the issue started will help the technician diagnose it faster.';
}

function isRetriableError(error) {
  const status = error?.response?.status;

  if (typeof status === 'number' && [408, 425, 429, 500, 502, 503, 504].includes(status)) {
    return true;
  }

  return Boolean(
    error?.code === 'ECONNRESET' ||
      error?.code === 'ETIMEDOUT' ||
      error?.code === 'ECONNABORTED' ||
      error?.code === 'ERR_CANCELED' ||
      error?.message?.toLowerCase?.().includes('timeout') ||
      error?.message?.toLowerCase?.().includes('network'),
  );
}

async function withRetry(operation, attempts = 2) {
  let lastError = null;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      if (attempt === attempts || !isRetriableError(error)) {
        break;
      }

      await new Promise((resolve) => setTimeout(resolve, 300 * attempt));
    }
  }

  throw lastError;
}

async function postGroqChat(body, stream, signal) {
  const apiKey = getGroqApiKey();

  if (!apiKey) {
    const error = new Error('Groq API key is missing.');
    error.statusCode = 503;
    error.code = 'groq_config_missing';
    throw error;
  }

  return axios.post(GROQ_API_URL, body, {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    responseType: stream ? 'stream' : 'json',
    timeout: REQUEST_TIMEOUT_MS,
    signal,
    validateStatus: (status) => status >= 200 && status < 300,
  });
}

function extractAssistantReply(data) {
  return (
    data?.choices?.[0]?.message?.content?.trim() ||
    data?.choices?.[0]?.delta?.content?.trim() ||
    ''
  );
}

function countApproxTokens(messages) {
  return messages.reduce((sum, message) => {
    const length = typeof message.content === 'string' ? message.content.length : 0;
    return sum + Math.ceil(length / 4);
  }, 0);
}

async function consumeGroqStream(stream, { onDelta, signal }) {
  return new Promise((resolve, reject) => {
    let buffer = '';
    let reply = '';
    let model = DEFAULT_MODEL;
    let settled = false;
    let idleTimer = null;

    const cleanup = () => {
      if (idleTimer) {
        clearTimeout(idleTimer);
        idleTimer = null;
      }
      stream.removeAllListeners('data');
      stream.removeAllListeners('end');
      stream.removeAllListeners('error');
      stream.removeAllListeners('close');
      if (signal) {
        signal.removeEventListener('abort', onAbort);
      }
    };

    const finalize = (value) => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      resolve(value);
    };

    const fail = (error) => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      reject(error);
    };

    const refreshIdleTimer = () => {
      if (idleTimer) {
        clearTimeout(idleTimer);
      }
      idleTimer = setTimeout(() => {
        fail(new Error('Groq stream timed out.'));
      }, STREAM_IDLE_TIMEOUT_MS);
    };

    const onAbort = () => {
      const error = new Error('Request cancelled.');
      error.code = 'ERR_CANCELED';
      fail(error);
    };

    if (signal) {
      if (signal.aborted) {
        onAbort();
        return;
      }
      signal.addEventListener('abort', onAbort, { once: true });
    }

    refreshIdleTimer();

    stream.on('data', (chunk) => {
      refreshIdleTimer();
      buffer += chunk.toString('utf8');

      let newlineIndex = buffer.indexOf('\n');
      while (newlineIndex !== -1) {
        const line = buffer.slice(0, newlineIndex).replace(/\r$/, '');
        buffer = buffer.slice(newlineIndex + 1);

        if (line.startsWith('data:')) {
          const payload = line.slice(5).trim();

          if (payload === '[DONE]') {
            finalize({
              reply: reply.trim(),
              model,
            });
            return;
          }

          if (payload) {
            try {
              const parsed = JSON.parse(payload);
              model = parsed?.model || model;

              const delta = parsed?.choices?.[0]?.delta?.content || '';
              if (delta) {
                reply += delta;
                if (typeof onDelta === 'function') {
                  onDelta(reply);
                }
              }

              const completedReply = parsed?.choices?.[0]?.message?.content;
              if (typeof completedReply === 'string' && completedReply.trim()) {
                reply = completedReply.trim();
              }
            } catch (error) {
              logger.warn('Groq stream frame parse failed', {
                error: error.message,
              });
            }
          }
        }

        newlineIndex = buffer.indexOf('\n');
      }
    });

    stream.on('end', () => {
      finalize({
        reply: reply.trim(),
        model,
      });
    });

    stream.on('close', () => {
      if (!settled) {
        const error = new Error('Groq stream closed unexpectedly.');
        error.code = 'stream_closed';
        fail(error);
      }
    });

    stream.on('error', (error) => {
      fail(error);
    });
  });
}

async function createGroqCompletion({
  messages,
  userId,
  requestId,
  stream = false,
  onDelta,
  signal,
}) {
  validateGroqConfig();

  const normalizedMessages = normalizeMessages(messages);
  const groqMessages = buildGroqMessages(normalizedMessages);
  const latestUserText = getLatestUserText(normalizedMessages);
  const start = Date.now();
  const tokenEstimate = countApproxTokens(groqMessages);

  const body = {
    model: DEFAULT_MODEL,
    messages: groqMessages,
    temperature: 0.3,
    max_completion_tokens: MAX_RESPONSE_TOKENS,
    top_p: 1,
    stream,
    service_tier: 'auto',
    user: userId || undefined,
  };

  logger.info('Groq request started', {
    requestId,
    userId,
    model: DEFAULT_MODEL,
    stream,
    messageCount: groqMessages.length,
    tokenEstimate,
  });

  try {
    if (!stream) {
      const response = await withRetry(() => postGroqChat(body, false, signal));
      const reply = extractAssistantReply(response.data);

      if (!reply) {
        const error = new Error('Groq returned an empty response.');
        error.statusCode = 502;
        error.code = 'groq_empty_response';
        throw error;
      }

      const durationMs = Date.now() - start;
      const result = {
        reply,
        proTip: buildProTip(latestUserText, reply),
        specialist: detectSpecialist(latestUserText, reply),
        model: response.data?.model || DEFAULT_MODEL,
        usage: response.data?.usage || null,
        streamed: false,
      };

      logger.info('Groq request completed', {
        requestId,
        userId,
        durationMs,
        streamed: false,
        model: result.model,
        tokenUsage: result.usage || null,
      });

      return result;
    }

    const response = await withRetry(() => postGroqChat(body, true, signal));

    if (response.headers?.['content-type']?.includes('text/event-stream')) {
      const streamedResult = await consumeGroqStream(response.data, {
        onDelta,
        signal,
      });

      if (!streamedResult.reply) {
        const error = new Error('Groq returned an empty streamed response.');
        error.statusCode = 502;
        error.code = 'groq_empty_stream';
        throw error;
      }

      const durationMs = Date.now() - start;
      const result = {
        reply: streamedResult.reply,
        proTip: buildProTip(latestUserText, streamedResult.reply),
        specialist: detectSpecialist(latestUserText, streamedResult.reply),
        model: streamedResult.model || DEFAULT_MODEL,
        usage: null,
        streamed: true,
      };

      logger.info('Groq stream completed', {
        requestId,
        userId,
        durationMs,
        streamed: true,
        model: result.model,
      });

      return result;
    }

    const bodyText = await new Promise((resolve, reject) => {
      let raw = '';
      response.data.on('data', (chunk) => {
        raw += chunk.toString('utf8');
      });
      response.data.on('end', () => resolve(raw));
      response.data.on('error', reject);
      if (signal) {
        signal.addEventListener(
          'abort',
          () => {
            const error = new Error('Request cancelled.');
            error.code = 'ERR_CANCELED';
            reject(error);
          },
          { once: true },
        );
      }
    });

    let parsed;
    try {
      parsed = bodyText ? JSON.parse(bodyText) : {};
    } catch (error) {
      logger.error('Failed to parse Groq JSON response', {
        requestId,
        error: error.message,
        responsePreview: bodyText.slice(0, 300),
      });
      const parseError = new Error('Groq returned malformed JSON.');
      parseError.statusCode = 502;
      parseError.code = 'groq_malformed_json';
      throw parseError;
    }

    const reply = extractAssistantReply(parsed);

    if (!reply) {
      const error = new Error('Groq returned an empty response.');
      error.statusCode = 502;
      error.code = 'groq_empty_response';
      throw error;
    }

    const durationMs = Date.now() - start;
    const result = {
      reply,
      proTip: buildProTip(latestUserText, reply),
      specialist: detectSpecialist(latestUserText, reply),
      model: parsed?.model || DEFAULT_MODEL,
      usage: parsed?.usage || null,
      streamed: true,
    };

    logger.info('Groq streamed fallback completed', {
      requestId,
      userId,
      durationMs,
      streamed: true,
      model: result.model,
    });

    return result;
  } catch (error) {
    logger.error('Groq request failed', {
      requestId,
      userId,
      stream,
      durationMs: Date.now() - start,
      code: error.code || null,
      statusCode: error.statusCode || error.status || null,
      message: error.message,
    });
    throw error;
  }
}

module.exports = {
  createGroqCompletion,
  buildSystemPrompt,
  buildProTip,
  detectSpecialist,
  validateGroqConfig,
  getGroqApiKey,
};
