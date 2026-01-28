// backend/src/index.ts

import { checkRateLimit, RATE_LIMITS } from './rate-limit';
import { sendVerificationEmail, generateVerificationCode } from './email';
import { initServerSetup, startRegistration, finishRegistration, startLogin, finishLogin } from './opaque';

export interface Env {
  // Legacy email verification (to be removed)
  CODES: KVNamespace;
  USERS: KVNamespace;
  AWS_ACCESS_KEY_ID: string;
  AWS_SECRET_ACCESS_KEY: string;
  AWS_REGION: string;
  FROM_EMAIL: string;

  // OPAQUE authentication
  CREDENTIALS: KVNamespace;  // OPAQUE password files
  BUNDLES: KVNamespace;      // Encrypted user data bundles
  LOGIN_STATES: KVNamespace; // Temporary login states (short TTL)
  OPAQUE_SERVER_SETUP: string; // Secret: server setup string

  // Shared
  RATE_LIMITS: KVNamespace;
}

// Legacy types (to be removed)
interface SendCodeRequest {
  email_hash: string;
  email: string;
}

interface VerifyCodeRequest {
  email_hash: string;
  code: string;
}

interface StoredCode {
  code: string;
  createdAt: number;
}

// OPAQUE request types
interface OpaqueRegisterStartRequest {
  clientIdentifier: string;
  registrationRequest: string;
}

interface OpaqueRegisterFinishRequest {
  clientIdentifier: string;
  registrationRecord: string;
  encryptedBundle?: string;
}

interface OpaqueLoginStartRequest {
  clientIdentifier: string;
  startLoginRequest: string;
}

interface OpaqueLoginFinishRequest {
  clientIdentifier: string;
  stateKey: string;
  finishLoginRequest: string;
}

const CODE_TTL_SECONDS = 300;
const LOGIN_STATE_TTL_SECONDS = 60;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Initialize OPAQUE server setup
    initServerSetup(env.OPAQUE_SERVER_SETUP);

    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400'
        }
      });
    }

    // Route handling
    if (request.method === 'POST') {
      // OPAQUE authentication routes
      if (path === '/api/auth/opaque/register/start') {
        return handleOpaqueRegisterStart(request, env);
      }
      if (path === '/api/auth/opaque/register/finish') {
        return handleOpaqueRegisterFinish(request, env);
      }
      if (path === '/api/auth/opaque/login/start') {
        return handleOpaqueLoginStart(request, env);
      }
      if (path === '/api/auth/opaque/login/finish') {
        return handleOpaqueLoginFinish(request, env);
      }

      // Legacy email verification routes (to be removed)
      if (path === '/api/auth/send-code') {
        return handleSendCode(request, env);
      }
      if (path === '/api/auth/verify-code') {
        return handleVerifyCode(request, env);
      }
    }

    return jsonResponse({ error: 'Not found' }, 404);
  }
};

// ============================================================================
// OPAQUE Authentication Handlers
// ============================================================================

async function handleOpaqueRegisterStart(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as OpaqueRegisterStartRequest;
    const { clientIdentifier, registrationRequest } = body;

    if (!clientIdentifier || typeof clientIdentifier !== 'string' || clientIdentifier.length !== 64) {
      return jsonResponse({ error: 'Invalid clientIdentifier' }, 400);
    }

    if (!registrationRequest || typeof registrationRequest !== 'string') {
      return jsonResponse({ error: 'Invalid registrationRequest' }, 400);
    }

    // Check if user already exists - but don't reveal this to prevent enumeration
    // We proceed with registration response either way
    const existing = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
    if (existing) {
      // User exists, but we still return a valid-looking response
      // The registration will fail at the finish step
      console.log(`[opaque/register/start] Existing user attempted re-registration: ${clientIdentifier.substring(0, 8)}...`);
    }

    const result = startRegistration(clientIdentifier, registrationRequest);

    return jsonResponse({
      registrationResponse: result.registrationResponse,
    });
  } catch (error) {
    console.error('[opaque/register/start] Error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
}

async function handleOpaqueRegisterFinish(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as OpaqueRegisterFinishRequest;
    const { clientIdentifier, registrationRecord, encryptedBundle } = body;

    if (!clientIdentifier || typeof clientIdentifier !== 'string' || clientIdentifier.length !== 64) {
      return jsonResponse({ error: 'Invalid clientIdentifier' }, 400);
    }

    if (!registrationRecord || typeof registrationRecord !== 'string') {
      return jsonResponse({ error: 'Invalid registrationRecord' }, 400);
    }

    // Check if user already exists
    const existing = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
    if (existing) {
      return jsonResponse({ error: 'Registration failed' }, 400);
    }

    const result = finishRegistration(registrationRecord);

    // Store password file
    await env.CREDENTIALS.put(`cred:${clientIdentifier}`, result.passwordFile);

    // Store initial bundle if provided
    if (encryptedBundle) {
      await env.BUNDLES.put(`bundle:${clientIdentifier}`, encryptedBundle);
    }

    console.log(`[opaque/register/finish] Registered user: ${clientIdentifier.substring(0, 8)}...`);

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('[opaque/register/finish] Error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
}

async function handleOpaqueLoginStart(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as OpaqueLoginStartRequest;
    const { clientIdentifier, startLoginRequest } = body;

    if (!clientIdentifier || typeof clientIdentifier !== 'string' || clientIdentifier.length !== 64) {
      return jsonResponse({ error: 'Invalid clientIdentifier' }, 400);
    }

    if (!startLoginRequest || typeof startLoginRequest !== 'string') {
      return jsonResponse({ error: 'Invalid startLoginRequest' }, 400);
    }

    // Rate limiting
    const rateLimit = await checkRateLimit(
      env.RATE_LIMITS,
      `opaque:login:${clientIdentifier}`,
      { maxRequests: 5, windowSeconds: 300 } // 5 attempts per 5 minutes
    );

    if (!rateLimit.allowed) {
      return jsonResponse(
        { error: 'Too many attempts', retry_after: rateLimit.resetAt },
        429,
        { 'Retry-After': String(rateLimit.resetAt - Math.floor(Date.now() / 1000)) }
      );
    }

    // Get password file
    const passwordFile = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
    if (!passwordFile) {
      // User doesn't exist - return generic error to prevent enumeration
      console.log(`[opaque/login/start] Unknown user: ${clientIdentifier.substring(0, 8)}...`);
      return jsonResponse({ error: 'Authentication failed' }, 401);
    }

    const result = startLogin(clientIdentifier, passwordFile, startLoginRequest);

    // Store server state temporarily (60 second TTL)
    const stateKey = `state:${clientIdentifier}:${Date.now()}`;
    await env.LOGIN_STATES.put(stateKey, result.serverState, {
      expirationTtl: LOGIN_STATE_TTL_SECONDS
    });

    return jsonResponse({
      loginResponse: result.credentialResponse,
      stateKey,
    });
  } catch (error) {
    console.error('[opaque/login/start] Error:', error);
    return jsonResponse({ error: 'Authentication failed' }, 401);
  }
}

async function handleOpaqueLoginFinish(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as OpaqueLoginFinishRequest;
    const { clientIdentifier, stateKey, finishLoginRequest } = body;

    if (!clientIdentifier || typeof clientIdentifier !== 'string' || clientIdentifier.length !== 64) {
      return jsonResponse({ error: 'Invalid clientIdentifier' }, 400);
    }

    if (!stateKey || typeof stateKey !== 'string') {
      return jsonResponse({ error: 'Invalid stateKey' }, 400);
    }

    if (!finishLoginRequest || typeof finishLoginRequest !== 'string') {
      return jsonResponse({ error: 'Invalid finishLoginRequest' }, 400);
    }

    // Get server state
    const serverState = await env.LOGIN_STATES.get(stateKey);
    if (!serverState) {
      return jsonResponse({ error: 'Session expired' }, 401);
    }

    // Delete state (one-time use)
    await env.LOGIN_STATES.delete(stateKey);

    try {
      const result = finishLogin(serverState, finishLoginRequest);

      // Get user's encrypted bundle
      const encryptedBundle = await env.BUNDLES.get(`bundle:${clientIdentifier}`);

      console.log(`[opaque/login/finish] Successful login: ${clientIdentifier.substring(0, 8)}...`);

      return jsonResponse({
        success: true,
        sessionKey: result.sessionKey,
        encryptedBundle,
      });
    } catch {
      // OPAQUE verification failed - wrong password
      console.log(`[opaque/login/finish] Failed verification: ${clientIdentifier.substring(0, 8)}...`);
      return jsonResponse({ error: 'Authentication failed' }, 401);
    }
  } catch (error) {
    console.error('[opaque/login/finish] Error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
}

// ============================================================================
// Legacy Email Verification Handlers (to be removed in Task 13)
// ============================================================================

async function handleSendCode(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as SendCodeRequest;
    const { email_hash, email } = body;

    if (!email_hash || typeof email_hash !== 'string' || email_hash.length !== 64) {
      return jsonResponse({ error: 'Invalid email_hash' }, 400);
    }

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return jsonResponse({ error: 'Invalid email' }, 400);
    }

    const clientIP = request.headers.get('CF-Connecting-IP') ?? 'unknown';

    const emailRateLimit = await checkRateLimit(
      env.RATE_LIMITS,
      `send:email:${email_hash}`,
      RATE_LIMITS.sendCode.perEmailHash
    );

    if (!emailRateLimit.allowed) {
      return jsonResponse(
        { error: 'Too many requests', retry_after: emailRateLimit.resetAt },
        429,
        { 'Retry-After': String(emailRateLimit.resetAt - Math.floor(Date.now() / 1000)) }
      );
    }

    const ipRateLimit = await checkRateLimit(
      env.RATE_LIMITS,
      `send:ip:${clientIP}`,
      RATE_LIMITS.sendCode.perIP
    );

    if (!ipRateLimit.allowed) {
      return jsonResponse(
        { error: 'Too many requests', retry_after: ipRateLimit.resetAt },
        429,
        { 'Retry-After': String(ipRateLimit.resetAt - Math.floor(Date.now() / 1000)) }
      );
    }

    const code = generateVerificationCode();
    const storedCode: StoredCode = {
      code,
      createdAt: Math.floor(Date.now() / 1000)
    };

    await env.CODES.put(`code:${email_hash}`, JSON.stringify(storedCode), {
      expirationTtl: CODE_TTL_SECONDS
    });

    const emailSent = await sendVerificationEmail(
      {
        awsAccessKeyId: env.AWS_ACCESS_KEY_ID,
        awsSecretAccessKey: env.AWS_SECRET_ACCESS_KEY,
        awsRegion: env.AWS_REGION,
        fromAddress: env.FROM_EMAIL
      },
      email,
      code
    );

    if (!emailSent) {
      console.error(`[send-code] Failed to send email for hash ${email_hash.substring(0, 8)}...`);
      return jsonResponse({ error: 'Failed to send email' }, 500);
    }

    console.log(`[send-code] Sent code to ${email} for hash ${email_hash.substring(0, 8)}...`);

    return jsonResponse({
      success: true,
      expires_in_seconds: CODE_TTL_SECONDS
    });

  } catch (error) {
    console.error('[send-code] Error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
}

async function handleVerifyCode(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json() as VerifyCodeRequest;
    const { email_hash, code } = body;

    if (!email_hash || typeof email_hash !== 'string' || email_hash.length !== 64) {
      return jsonResponse({ error: 'Invalid email_hash' }, 400);
    }

    if (!code || typeof code !== 'string' || !/^\d{6}$/.test(code)) {
      return jsonResponse({ error: 'Invalid code format' }, 400);
    }

    const rateLimit = await checkRateLimit(
      env.RATE_LIMITS,
      `verify:${email_hash}`,
      RATE_LIMITS.verifyCode.perEmailHash
    );

    if (!rateLimit.allowed) {
      return jsonResponse(
        { error: 'Too many attempts', retry_after: rateLimit.resetAt },
        429,
        { 'Retry-After': String(rateLimit.resetAt - Math.floor(Date.now() / 1000)) }
      );
    }

    const storedData = await env.CODES.get<StoredCode>(`code:${email_hash}`, 'json');

    if (!storedData) {
      return jsonResponse({ error: 'Code expired or not found' }, 410);
    }

    if (storedData.code !== code) {
      return jsonResponse({ error: 'Invalid code' }, 400);
    }

    await env.CODES.delete(`code:${email_hash}`);

    const existingUser = await env.USERS.get(`user:${email_hash}`);
    const isReturningUser = existingUser !== null;

    if (!isReturningUser) {
      await env.USERS.put(`user:${email_hash}`, JSON.stringify({
        createdAt: Math.floor(Date.now() / 1000)
      }));
    }

    console.log(`[verify-code] Verified for hash ${email_hash.substring(0, 8)}..., returning: ${isReturningUser}`);

    return jsonResponse({
      success: true,
      is_returning_user: isReturningUser
    });

  } catch (error) {
    console.error('[verify-code] Error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
}

// ============================================================================
// Helpers
// ============================================================================

function jsonResponse(
  data: object,
  status = 200,
  extraHeaders: Record<string, string> = {}
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      ...extraHeaders
    }
  });
}
