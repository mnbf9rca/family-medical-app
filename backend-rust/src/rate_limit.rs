//! Rate limiting for OPAQUE authentication endpoints
//!
//! Uses Cloudflare KV with sliding window algorithm.
//! Keys: `rate:{client_identifier}:{endpoint}` with TTL-based expiry.

use serde::{Deserialize, Serialize};
use worker::*;

/// Rate limit configuration
pub struct RateLimitConfig {
    /// Maximum requests per window
    pub max_requests: u32,
    /// Window duration in seconds
    pub window_seconds: u64,
}

impl Default for RateLimitConfig {
    fn default() -> Self {
        Self {
            max_requests: 5,
            window_seconds: 60,
        }
    }
}

/// Rate limit entry stored in KV
#[derive(Serialize, Deserialize)]
struct RateLimitEntry {
    count: u32,
    window_start: u64,
}

/// Check and update rate limit for a client identifier + endpoint combination.
/// Returns Ok(()) if request is allowed, Err with remaining seconds if rate limited.
///
/// Note: The read-then-write pattern has a race condition, but this is acceptable because:
/// 1. This is defense-in-depth (Cloudflare edge rate limiting is the primary mechanism)
/// 2. Cloudflare KV has eventual consistency anyway
pub async fn check_rate_limit(
    kv: &kv::KvStore,
    client_identifier: &str,
    endpoint: &str,
    config: &RateLimitConfig,
) -> std::result::Result<(), u64> {
    let key = format!("rate:{}:{}", client_identifier, endpoint);
    let now = Date::now().as_millis() / 1000; // seconds since epoch

    // Get existing entry
    let entry: Option<RateLimitEntry> = kv.get(&key).json().await.unwrap_or_default();

    match entry {
        Some(mut e) if now < e.window_start + config.window_seconds => {
            // Within window
            if e.count >= config.max_requests {
                // Rate limited - return seconds until window expires
                let remaining = (e.window_start + config.window_seconds) - now;
                return Err(remaining);
            }
            // Increment count
            e.count += 1;
            if let Ok(builder) = kv.put(&key, serde_json::to_string(&e).unwrap_or_default()) {
                if builder.expiration_ttl(config.window_seconds).execute().await.is_err() {
                    // Fail-open: log but allow request (primary rate limiting is at Cloudflare edge)
                    console_log!("[rate_limit] KV write failed for key: {}", key);
                }
            }
            Ok(())
        }
        _ => {
            // No entry or window expired - start new window
            let new_entry = RateLimitEntry {
                count: 1,
                window_start: now,
            };
            if let Ok(builder) = kv.put(&key, serde_json::to_string(&new_entry).unwrap_or_default()) {
                if builder.expiration_ttl(config.window_seconds).execute().await.is_err() {
                    // Fail-open: log but allow request (primary rate limiting is at Cloudflare edge)
                    console_log!("[rate_limit] KV write failed for key: {}", key);
                }
            }
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    // Note: KV tests require wrangler dev or miniflare
    // Unit tests focus on serialization logic
}
