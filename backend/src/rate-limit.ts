// backend/src/rate-limit.ts

export interface RateLimitConfig {
  maxRequests: number;
  windowSeconds: number;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
}

/**
 * Check and increment rate limit counter
 * Uses sliding window algorithm with KV storage
 */
export async function checkRateLimit(
  kv: KVNamespace,
  key: string,
  config: RateLimitConfig
): Promise<RateLimitResult> {
  const now = Math.floor(Date.now() / 1000);
  const windowStart = now - config.windowSeconds;

  // Get current counter
  const counterKey = `rate:${key}`;
  const stored = await kv.get<{ count: number; timestamps: number[] }>(counterKey, 'json');

  // Filter to timestamps within window
  const timestamps = stored?.timestamps?.filter(t => t > windowStart) ?? [];

  if (timestamps.length >= config.maxRequests) {
    const oldestInWindow = Math.min(...timestamps);
    return {
      allowed: false,
      remaining: 0,
      resetAt: oldestInWindow + config.windowSeconds
    };
  }

  // Add current timestamp and save
  timestamps.push(now);
  await kv.put(counterKey, JSON.stringify({ count: timestamps.length, timestamps }), {
    expirationTtl: config.windowSeconds + 60 // Buffer for cleanup
  });

  return {
    allowed: true,
    remaining: config.maxRequests - timestamps.length,
    resetAt: now + config.windowSeconds
  };
}

// Rate limit configurations
export const RATE_LIMITS = {
  sendCode: {
    perEmailHash: { maxRequests: 3, windowSeconds: 3600 },  // 3 per hour per email
    perIP: { maxRequests: 10, windowSeconds: 3600 }         // 10 per hour per IP
  },
  verifyCode: {
    perEmailHash: { maxRequests: 5, windowSeconds: 3600 }   // 5 attempts per hour
  }
};
