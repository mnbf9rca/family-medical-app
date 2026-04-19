//! Rate limiting for OPAQUE authentication endpoints
//!
//! Uses Cloudflare KV with sliding window algorithm.
//! Keys: `rate:{client_identifier}:{endpoint}` with TTL-based expiry.
//!
//! ## Fail-open policy
//!
//! This module fails open on every KV error (get failure, deserialization
//! failure, put failure). Rationale + alerting contract are documented in
//! `docs/adr/adr-0011-opaque-zero-knowledge-auth.md` §"Rate-limiter
//! fail-open policy and alerting contract". The three failure modes are
//! emitted as distinct log lines with a `counter=` prefix so operators can
//! wire up separate alerts for transient KV outages vs. deserialization
//! errors (schema drift / poisoning).
//!
//! ## Visibility
//!
//! The module is `pub` only when the `testing` feature is enabled (see
//! `src/lib.rs`), so the items below marked `pub` are *not* part of the
//! release-build public API — they are only reachable from the integration
//! test in `tests/rate_limit_error_logging_test.rs`.

use serde::{Deserialize, Serialize};
use worker::*;

/// Default rate-limit ladder: 5 requests per 60-second window.
/// See ADR-0011 §"Rate-limit ladder" for rationale.
pub const DEFAULT_MAX_REQUESTS: u32 = 5;
pub const DEFAULT_WINDOW_SECONDS: u64 = 60;

/// Stricter ladder for registration endpoints: 3 requests per
/// 300-second (5-minute) window. See ADR-0011 §"Rate-limit ladder"
/// for why registration tolerates fewer attempts per window.
pub const REGISTRATION_MAX_REQUESTS: u32 = 3;
pub const REGISTRATION_WINDOW_SECONDS: u64 = 300;

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
            max_requests: DEFAULT_MAX_REQUESTS,
            window_seconds: DEFAULT_WINDOW_SECONDS,
        }
    }
}

/// Rate limit entry stored in KV.
#[derive(Serialize, Deserialize, Debug)]
pub struct RateLimitEntry {
    count: u32,
    window_start: u64,
}

/// Outcome of a single `check_rate_limit_inner` invocation.
///
/// `decision` drives the control-flow response to the caller. `diagnostics`
/// enumerates any KV-level failures observed during the check so the outer
/// wrapper can emit one log line per failure, each tagged with a distinct
/// `counter=` value for alerting.
#[derive(Debug, PartialEq, Eq)]
pub struct RateLimitOutcome {
    /// `None` = allow, `Some(retry_after_secs)` = deny.
    pub decision: Option<u64>,
    /// Zero or more observability events from this check.
    pub diagnostics: Vec<RateLimitDiagnostic>,
}

/// A KV-layer failure observed while checking the rate limit.
///
/// These are emitted as distinct log lines so operators can alert on
/// each independently. See ADR-0011 §"Rate-limiter fail-open policy and
/// alerting contract" for the alerting thresholds.
///
/// Variants drop the `Error` suffix (per clippy::enum_variant_names) —
/// the enum name already communicates "failure observation". The `Counter`
/// doc line pins the externally-observable name emitted to logs.
#[derive(Debug, PartialEq, Eq)]
pub enum RateLimitDiagnostic {
    /// KV `get` returned a transport error. Transient Cloudflare infra failure.
    /// Counter: `rate_limit_kv_get_error`. Severity: warn.
    KvGet { key: String, err: String },
    /// Stored bytes failed to deserialize. Schema drift or poisoning.
    /// Counter: `rate_limit_deser_error`. Severity: error.
    Deser { key: String, err: String },
    /// KV `put` returned a transport error. Transient Cloudflare infra failure.
    /// Counter: `rate_limit_kv_put_error`. Severity: warn.
    KvPut { key: String, err: String },
}

/// Minimal abstraction over the KV operations the rate limiter needs.
///
/// Exists solely so the core logic in [`check_rate_limit_inner`] can be
/// exercised natively (the real `worker::kv::KvStore` is a wasm-only
/// wrapper around a JS object). There is exactly one production impl
/// (`&kv::KvStore`, below) and one test impl (in
/// `tests/rate_limit_error_logging_test.rs`).
///
/// Cloudflare Workers are single-threaded per isolate, so we don't need
/// `Send` bounds on the returned futures — hence `async fn` directly.
#[allow(async_fn_in_trait)]
pub trait RateLimitStore {
    async fn get_entry(&self, key: &str) -> std::result::Result<GetEntryResult, String>;
    async fn put_entry(&self, key: &str, entry: &RateLimitEntry, ttl_seconds: u64) -> std::result::Result<(), String>;
}

/// Result of a rate-limit `get` attempt, separating "absent" from
/// "present-but-undeserializable" so the caller can emit distinct counters.
pub enum GetEntryResult {
    /// Key absent — start a fresh window.
    Missing,
    /// Key present and parsed successfully.
    Found(RateLimitEntry),
    /// Key present but bytes failed to deserialize. The stored string is
    /// elided (too large to log); only the error is surfaced. Named
    /// `Undeserializable` rather than `DeserError` to satisfy
    /// `clippy::enum_variant_names` (the sibling `Missing`/`Found` variants
    /// are non-error states).
    Undeserializable(String),
}

impl RateLimitStore for &kv::KvStore {
    async fn get_entry(&self, key: &str) -> std::result::Result<GetEntryResult, String> {
        match self.get(key).text().await {
            Ok(Some(text)) => match serde_json::from_str::<RateLimitEntry>(&text) {
                Ok(entry) => Ok(GetEntryResult::Found(entry)),
                Err(err) => Ok(GetEntryResult::Undeserializable(err.to_string())),
            },
            Ok(None) => Ok(GetEntryResult::Missing),
            Err(err) => Err(err.to_string()),
        }
    }

    async fn put_entry(&self, key: &str, entry: &RateLimitEntry, ttl_seconds: u64) -> std::result::Result<(), String> {
        let payload = serde_json::to_string(entry).map_err(|e| e.to_string())?;
        let builder = self.put(key, payload).map_err(|e| e.to_string())?;
        builder
            .expiration_ttl(ttl_seconds)
            .execute()
            .await
            .map_err(|e| e.to_string())
    }
}

/// Check and update rate limit for a client identifier + endpoint combination.
/// Returns Ok(()) if request is allowed, Err with remaining seconds if rate limited.
///
/// Note: The read-then-write pattern has a race condition, but this is acceptable because:
/// 1. This is defense-in-depth (Cloudflare edge rate limiting is the primary mechanism)
/// 2. Cloudflare KV has eventual consistency anyway
///
/// Fail-open on KV errors: see module-level docs and ADR-0011.
pub async fn check_rate_limit(
    kv: &kv::KvStore,
    client_identifier: &str,
    endpoint: &str,
    config: &RateLimitConfig,
) -> std::result::Result<(), u64> {
    let key = format!("rate:{}:{}", client_identifier, endpoint);
    let now = Date::now().as_millis() / 1000; // seconds since epoch
    let outcome = check_rate_limit_inner(&kv, &key, now, config).await;
    for diag in &outcome.diagnostics {
        emit_diagnostic(diag);
    }
    match outcome.decision {
        Some(retry_after) => Err(retry_after),
        None => Ok(()),
    }
}

/// Pure-ish core logic of [`check_rate_limit`]: takes an injectable store
/// and an explicit `now`, returns an outcome describing both the decision
/// and any KV failures that occurred. Separated from [`check_rate_limit`]
/// so it can be tested natively with a fake store.
pub async fn check_rate_limit_inner<S: RateLimitStore>(
    store: &S,
    key: &str,
    now: u64,
    config: &RateLimitConfig,
) -> RateLimitOutcome {
    let mut diagnostics: Vec<RateLimitDiagnostic> = Vec::new();

    let existing: Option<RateLimitEntry> = match store.get_entry(key).await {
        Ok(GetEntryResult::Found(entry)) => Some(entry),
        Ok(GetEntryResult::Missing) => None,
        Ok(GetEntryResult::Undeserializable(err)) => {
            diagnostics.push(RateLimitDiagnostic::Deser {
                key: key.to_string(),
                err,
            });
            None
        }
        Err(err) => {
            diagnostics.push(RateLimitDiagnostic::KvGet {
                key: key.to_string(),
                err,
            });
            None
        }
    };

    let (next_entry, decision) = match existing {
        Some(mut e) if now < e.window_start + config.window_seconds => {
            // Within window
            if e.count >= config.max_requests {
                // Rate limited - no write, return seconds until window expires
                let remaining = (e.window_start + config.window_seconds) - now;
                return RateLimitOutcome {
                    decision: Some(remaining),
                    diagnostics,
                };
            }
            e.count += 1;
            (e, None)
        }
        _ => {
            // No entry, window expired, or prior entry unusable - start a fresh window.
            let fresh = RateLimitEntry {
                count: 1,
                window_start: now,
            };
            (fresh, None)
        }
    };

    if let Err(err) = store.put_entry(key, &next_entry, config.window_seconds).await {
        diagnostics.push(RateLimitDiagnostic::KvPut {
            key: key.to_string(),
            err,
        });
    }

    RateLimitOutcome { decision, diagnostics }
}

/// Translate a diagnostic into a `console_*!` log line. The `counter=` prefix
/// is load-bearing: ops dashboards grep for it to build per-counter alerts.
fn emit_diagnostic(diag: &RateLimitDiagnostic) {
    match diag {
        RateLimitDiagnostic::KvGet { key, err } => {
            console_warn!(
                "[rate_limit] counter=rate_limit_kv_get_error key={} err={} (fail-open)",
                key,
                err
            );
        }
        RateLimitDiagnostic::Deser { key, err } => {
            console_error!(
                "[rate_limit] counter=rate_limit_deser_error key={} err={} (overwriting on next write)",
                key,
                err
            );
        }
        RateLimitDiagnostic::KvPut { key, err } => {
            console_warn!(
                "[rate_limit] counter=rate_limit_kv_put_error key={} err={} (fail-open)",
                key,
                err
            );
        }
    }
}
