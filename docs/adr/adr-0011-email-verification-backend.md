# Email Verification Backend Architecture

## Status

**Status**: Superseded by [ADR-0012](adr-0012-opaque-zero-knowledge-auth.md)

## Context

The Family Medical App needs to verify user email addresses during account creation and device registration. This serves two purposes:

1. **Identity verification**: Confirm the user has access to the claimed email address
2. **Returning user detection**: Identify when a user sets up a new device vs creates a new account

The app already has client-side infrastructure for email verification (EmailVerificationService.swift) but needs a backend to actually send codes and verify them.

Key constraints:

- Must integrate with existing iOS client API contract
- Should minimize email storage for privacy
- Must protect against abuse (spam, brute force)
- Should work with Cloudflare Workers (existing domain infrastructure)

## Decision

We will implement a Cloudflare Workers backend with the following design:

### Architecture

- **Cloudflare Workers**: Serverless functions at the edge for low latency
- **Cloudflare KV**: Key-value storage for verification codes (5min TTL), rate limits (1hr TTL), and user registry
- **AWS SES**: Email delivery service for sending verification codes

### API Design

- `POST /api/auth/send-code`: Client sends both email hash (for storage key) and actual email (for sending)
- `POST /api/auth/verify-code`: Client sends email hash and 6-digit code

### Security Measures

- **Rate limiting**: 3 send requests/hour per email, 10/hour per IP, 5 verify attempts/hour
- **6-digit codes**: Server-generated using crypto.getRandomValues()
- **One-time use**: Codes deleted immediately after successful verification
- **5-minute expiry**: Auto-deleted via KV TTL

### Privacy Approach

- Email used only for sending, not persisted in KV
- Email hash used as storage key (cannot reverse to get email)
- User registry stores only hashes (for returning user detection)

### Why 6-digit code over magic link

- More resistant to phishing (user types code, can't click malicious link)
- Works cross-device (read code on phone, type on iPad)
- Rate limiting makes brute force impractical

## Consequences

### Positive

- Low latency (Cloudflare edge network)
- Minimal email storage (only hashes persisted)
- Strong abuse protection via rate limiting
- Simple deployment (wrangler CLI)
- Cost effective (Cloudflare Workers free tier likely sufficient)

### Negative

- Requires AWS SES setup and domain verification
- Server sees actual email during send (unavoidable for email delivery)
- KV eventual consistency could theoretically cause issues (unlikely in practice)

### Neutral

- Backend is separate deployment from iOS app
- Requires Cloudflare account and API tokens
