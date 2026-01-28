// backend/src/index.ts

import { checkRateLimit, RATE_LIMITS } from './rate-limit';
import { sendVerificationEmail, generateVerificationCode } from './email';

export interface Env {
  CODES: KVNamespace;
  RATE_LIMITS: KVNamespace;
  USERS: KVNamespace;
  AWS_ACCESS_KEY_ID: string;
  AWS_SECRET_ACCESS_KEY: string;
  AWS_REGION: string;
  FROM_EMAIL: string;
}

interface SendCodeRequest {
  email_hash: string;
  email: string;  // Actual email for sending verification code
}

interface VerifyCodeRequest {
  email_hash: string;
  code: string;
}

interface StoredCode {
  code: string;
  createdAt: number;
}

const CODE_TTL_SECONDS = 300; // 5 minutes

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
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

    // Get client IP for rate limiting
    const clientIP = request.headers.get('CF-Connecting-IP') ?? 'unknown';

    // Check rate limits
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

    // Generate and store code
    const code = generateVerificationCode();
    const storedCode: StoredCode = {
      code,
      createdAt: Math.floor(Date.now() / 1000)
    };

    await env.CODES.put(`code:${email_hash}`, JSON.stringify(storedCode), {
      expirationTtl: CODE_TTL_SECONDS
    });

    // Send verification email
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

    // Check rate limit
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

    // Look up stored code
    const storedData = await env.CODES.get<StoredCode>(`code:${email_hash}`, 'json');

    if (!storedData) {
      // Code doesn't exist or expired (KV auto-deletes after TTL)
      return jsonResponse({ error: 'Code expired or not found' }, 410);
    }

    // Verify code matches
    if (storedData.code !== code) {
      return jsonResponse({ error: 'Invalid code' }, 400);
    }

    // Code is valid - delete it (one-time use)
    await env.CODES.delete(`code:${email_hash}`);

    // Check if returning user
    const existingUser = await env.USERS.get(`user:${email_hash}`);
    const isReturningUser = existingUser !== null;

    // If new user, register the email hash
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
