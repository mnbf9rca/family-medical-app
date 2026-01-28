// backend/src/index.ts

import { checkRateLimit } from './rate-limit';
import { initServerSetup, startRegistration, finishRegistration, startLogin, finishLogin } from './opaque';

export interface Env {
  // OPAQUE authentication
  CREDENTIALS: KVNamespace;  // OPAQUE password files
  BUNDLES: KVNamespace;      // Encrypted user data bundles
  LOGIN_STATES: KVNamespace; // Temporary login states (short TTL)
  OPAQUE_SERVER_SETUP: string; // Secret: server setup string

  // Rate limiting
  RATE_LIMITS: KVNamespace;
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
      if (path === '/auth/opaque/register/start') {
        return handleOpaqueRegisterStart(request, env);
      }
      if (path === '/auth/opaque/register/finish') {
        return handleOpaqueRegisterFinish(request, env);
      }
      if (path === '/auth/opaque/login/start') {
        return handleOpaqueLoginStart(request, env);
      }
      if (path === '/auth/opaque/login/finish') {
        return handleOpaqueLoginFinish(request, env);
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
