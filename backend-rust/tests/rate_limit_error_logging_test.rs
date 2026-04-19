//! Integration tests for rate-limiter KV failure-mode observability.
//!
//! The rate limiter in `src/rate_limit.rs` fails open on every KV error but
//! must emit three distinct diagnostics so operators can alert on them
//! independently:
//!
//! - `rate_limit_kv_get_error`  — KV backend unavailable on read (warn).
//! - `rate_limit_deser_error`   — stored bytes failed to deserialize (error).
//! - `rate_limit_kv_put_error`  — KV backend unavailable on write (warn).
//!
//! Missing-key reads must NOT emit a diagnostic — they are the normal
//! "start a fresh window" path.
//!
//! These tests drive the pure `check_rate_limit_inner` core with a
//! controllable fake store. The `rate_limit` module is reachable because
//! `src/lib.rs` makes it `pub` under the `testing` feature; in release
//! builds it is private and these symbols are not part of the worker's
//! public API. Control flow is unchanged by this PR: the limiter still
//! fails open; the tests just pin the observability contract.
//!
//! Requires: `cargo test --features testing` (wired via `required-features`
//! on the `[[test]]` entry in `backend-rust/Cargo.toml`, so a bare
//! `cargo test rate_limit_error_logging --features testing` picks it up).

use recordwell_opaque_worker::rate_limit::{
    check_rate_limit_inner, GetEntryResult, RateLimitConfig, RateLimitEntry, RateLimitFailure, RateLimitStore,
};
use std::cell::RefCell;

/// Controllable fake KV store. Each operation can be scripted to return
/// success-missing, success-found, deser-error, or transport error.
#[derive(Default)]
struct FakeStore {
    get_result: RefCell<Option<FakeGetResult>>,
    put_result: RefCell<Option<FakePutResult>>,
    put_calls: RefCell<u32>,
}

enum FakeGetResult {
    Missing,
    Found(RateLimitEntry),
    Undeserializable(String),
    Transport(String),
}

enum FakePutResult {
    Ok,
    Transport(String),
}

impl FakeStore {
    fn with_get(self, g: FakeGetResult) -> Self {
        *self.get_result.borrow_mut() = Some(g);
        self
    }
    fn with_put(self, p: FakePutResult) -> Self {
        *self.put_result.borrow_mut() = Some(p);
        self
    }
}

impl RateLimitStore for FakeStore {
    async fn get_entry(&self, _key: &str) -> std::result::Result<GetEntryResult, String> {
        let r = self
            .get_result
            .borrow_mut()
            .take()
            .expect("FakeStore: get_entry called without a scripted result");
        match r {
            FakeGetResult::Missing => Ok(GetEntryResult::Missing),
            FakeGetResult::Found(entry) => Ok(GetEntryResult::Found(entry)),
            FakeGetResult::Undeserializable(err) => Ok(GetEntryResult::Undeserializable(err)),
            FakeGetResult::Transport(err) => Err(err),
        }
    }

    async fn put_entry(
        &self,
        _key: &str,
        _entry: &RateLimitEntry,
        _ttl_seconds: u64,
    ) -> std::result::Result<(), String> {
        *self.put_calls.borrow_mut() += 1;
        let r = self.put_result.borrow_mut().take().unwrap_or(FakePutResult::Ok);
        match r {
            FakePutResult::Ok => Ok(()),
            FakePutResult::Transport(err) => Err(err),
        }
    }
}

fn default_config() -> RateLimitConfig {
    RateLimitConfig::default()
}

/// Tiny async runner to drive `check_rate_limit_inner` without needing a
/// full tokio runtime at test-time. The inner function uses only `async fn`
/// in trait methods backed by our `RefCell` fake (no timers, no IO, no
/// channels), so a trivial executor suffices: every poll either completes
/// (all operations are synchronous on the fake) or we spin.
fn block_on<F: std::future::Future>(fut: F) -> F::Output {
    use std::sync::Arc;
    use std::task::{Context, Poll, Wake, Waker};

    struct NoopWaker;
    impl Wake for NoopWaker {
        fn wake(self: Arc<Self>) {}
    }
    let waker: Waker = Arc::new(NoopWaker).into();
    let mut ctx = Context::from_waker(&waker);
    let mut fut = Box::pin(fut);
    match fut.as_mut().poll(&mut ctx) {
        Poll::Ready(v) => v,
        Poll::Pending => panic!(
            "block_on: future returned Pending; this runner only supports sync futures — use a real async runtime if you need true async"
        ),
    }
}

#[test]
fn rate_limit_error_logging_missing_key_emits_no_diagnostic() {
    // Scenario: no existing entry in KV. Expected: fresh window (count=1),
    // no diagnostic emitted, request allowed.
    let store = FakeStore::default()
        .with_get(FakeGetResult::Missing)
        .with_put(FakePutResult::Ok);
    let config = default_config();

    let outcome = block_on(check_rate_limit_inner(&store, "rate:abc:login", 1_000, &config));

    assert_eq!(outcome.decision, None, "missing key must allow the request");
    assert!(
        outcome.diagnostics.is_empty(),
        "missing key is the normal fresh-window path — no diagnostic expected, got {:?}",
        outcome.diagnostics
    );
    assert_eq!(*store.put_calls.borrow(), 1, "fresh window must write a new entry");
}

#[test]
fn rate_limit_error_logging_kv_get_error_emits_get_diagnostic_and_allows() {
    // Scenario: KV backend returns a transport error on read. Expected:
    // kv_get_error diagnostic, fail-open (request allowed), fresh window
    // written.
    let store = FakeStore::default()
        .with_get(FakeGetResult::Transport("KV unreachable".into()))
        .with_put(FakePutResult::Ok);
    let config = default_config();

    let outcome = block_on(check_rate_limit_inner(&store, "rate:xyz:login", 2_000, &config));

    assert_eq!(outcome.decision, None, "fail-open on KV get error");
    assert_eq!(outcome.diagnostics.len(), 1, "exactly one diagnostic expected");
    match &outcome.diagnostics[0] {
        RateLimitFailure::KvGet { key, err } => {
            assert_eq!(key, "rate:xyz:login");
            assert!(
                err.contains("KV unreachable"),
                "diagnostic must carry the underlying error message: {err}"
            );
        }
        other => panic!("expected KvGet, got {other:?}"),
    }
}

#[test]
fn rate_limit_error_logging_deser_error_emits_deser_diagnostic_and_allows() {
    // Scenario: stored bytes fail to deserialize (schema drift or poisoning).
    // Expected: deser_error diagnostic, fail-open, fresh window written.
    // Writing the fresh entry overwrites the poisoned bytes — this is the
    // self-limiting property documented in ADR-0011.
    let store = FakeStore::default()
        .with_get(FakeGetResult::Undeserializable("invalid type: null".into()))
        .with_put(FakePutResult::Ok);
    let config = default_config();

    let outcome = block_on(check_rate_limit_inner(&store, "rate:pq:register", 3_000, &config));

    assert_eq!(outcome.decision, None, "fail-open on deser error");
    assert_eq!(outcome.diagnostics.len(), 1, "exactly one diagnostic expected");
    match &outcome.diagnostics[0] {
        RateLimitFailure::Deser { key, err } => {
            assert_eq!(key, "rate:pq:register");
            assert!(err.contains("invalid type"), "must preserve serde error text");
        }
        other => panic!("expected Deser, got {other:?}"),
    }
    assert_eq!(
        *store.put_calls.borrow(),
        1,
        "self-limiting overwrite: must write a fresh entry after a poisoned read"
    );
}

#[test]
fn rate_limit_error_logging_kv_put_error_emits_put_diagnostic_and_allows() {
    // Scenario: read succeeds (missing key) but write fails. Expected:
    // kv_put_error diagnostic, fail-open (request allowed).
    let store = FakeStore::default()
        .with_get(FakeGetResult::Missing)
        .with_put(FakePutResult::Transport("KV write throttled".into()));
    let config = default_config();

    let outcome = block_on(check_rate_limit_inner(&store, "rate:lmn:login", 4_000, &config));

    assert_eq!(outcome.decision, None, "fail-open on KV put error");
    assert_eq!(outcome.diagnostics.len(), 1, "exactly one diagnostic expected");
    match &outcome.diagnostics[0] {
        RateLimitFailure::KvPut { key, err } => {
            assert_eq!(key, "rate:lmn:login");
            assert!(err.contains("throttled"));
        }
        other => panic!("expected KvPut, got {other:?}"),
    }
}

#[test]
fn rate_limit_error_logging_under_limit_increment_emits_no_failure() {
    // Scenario: existing entry within its window, count below max. Expected:
    // request allowed, exactly one put (the incremented entry), no failure
    // diagnostics. Exercises the `Found(entry)` + `count < max_requests`
    // control-flow branch that the failure-mode tests do not cover.
    let config = default_config();
    let now: u64 = 10_000;
    let existing = RateLimitEntry::new_for_testing(config.max_requests - 1, now - 5);
    let store = FakeStore::default()
        .with_get(FakeGetResult::Found(existing))
        .with_put(FakePutResult::Ok);

    let outcome = block_on(check_rate_limit_inner(&store, "rate:uvw:login", now, &config));

    assert_eq!(outcome.decision, None, "under-limit request must be allowed");
    assert!(
        outcome.diagnostics.is_empty(),
        "happy-path increment must emit no failure diagnostics, got {:?}",
        outcome.diagnostics
    );
    assert_eq!(*store.put_calls.borrow(), 1, "increment must persist the updated entry");
}

#[test]
fn rate_limit_error_logging_at_limit_denial_emits_no_failure() {
    // Scenario: existing entry within its window, count already at max.
    // Expected: request denied with retry_after until window expiry, zero
    // puts (early return), no failure diagnostics. Exercises the
    // `Found(entry)` + `count >= max_requests` branch.
    let config = default_config();
    let window_start: u64 = 10_000;
    let now: u64 = window_start + 10; // 10s into the window
    let expected_retry_after = config.window_seconds - (now - window_start);
    let existing = RateLimitEntry::new_for_testing(config.max_requests, window_start);
    let store = FakeStore::default().with_get(FakeGetResult::Found(existing));

    let outcome = block_on(check_rate_limit_inner(&store, "rate:rst:login", now, &config));

    assert_eq!(
        outcome.decision,
        Some(expected_retry_after),
        "at-limit request must be denied with retry_after until window expiry"
    );
    assert!(
        outcome.diagnostics.is_empty(),
        "denied request must emit no failure diagnostics, got {:?}",
        outcome.diagnostics
    );
    assert_eq!(
        *store.put_calls.borrow(),
        0,
        "denied request must not write (early return)"
    );
}
