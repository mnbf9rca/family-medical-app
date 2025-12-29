# Architecture Decision Records (ADRs)

This directory contains architecture decision records for the Family Medical App.

## What is an ADR?

ADRs document significant architectural decisions, their context, and consequences. They create a historical record of why we made certain choices.

## Creating a New ADR

1. Copy `adr-template.md` to a new file with format: `adr-NNNN-short-title.md`
2. Follow the template to fill in all sections
3. Add a link to your ADR in the relevant section below
4. If no relevant section exists, create one

## Index

### Security & Cryptography

- [ADR-0001: Cryptographic Architecture Must Be Designed Before Implementation](adr-0001-crypto-architecture-first.md) - **Accepted** (2025-12-19)
  - Establishes "crypto-first architecture" principle: design complete cryptographic architecture before any implementation
- [ADR-0002: Key Hierarchy and Derivation](adr-0002-key-hierarchy.md) - **Proposed** (2025-12-19)
  - Defines three-tier key hierarchy: Master Key → User Identity (Curve25519) → Family Member Keys → Medical Records
  - Argon2id (via Swift-Sodium) for password-based key derivation
  - Per-family-member data encryption keys for granular access control
  - ECDH-based key wrapping for sharing over insecure channels
  - Re-encryption strategy for cryptographic access revocation
- [ADR-0003: Multi-User Sharing Model](adr-0003-multi-user-sharing-model.md) - **Proposed** (2025-12-20)
  - TOFU (Trust On First Use) for public key exchange with optional verification codes
  - Email invitation flow with embedded public keys (works over insecure channels)
  - ECDH + HKDF + AES-KeyWrap for Family Member Key distribution
  - Per-family-member sharing granularity (e.g., "share Emma's records")
  - Security vs. UX trade-offs: convenience prioritized for medical records (static data threat model)
  - Async operation (users never need to be online simultaneously)
  - Content zero-knowledge (server sees social graph metadata, not medical content)
- [ADR-0005: Access Revocation and Cryptographic Key Rotation](adr-0005-access-revocation.md) - **Proposed** (2025-12-20)
  - Full re-encryption with new FMK for true cryptographic revocation (not UI-only)
  - Performance: ~500ms for 500 records (acceptable for user-initiated action)
  - Realtime propagation across all devices (immediate revocation)
  - Atomic revocation with server-side transactions (all-or-nothing)
  - Encrypted audit trail for compliance and transparency
  - Limitation: Historical data downloaded before revocation remains accessible (fundamental E2EE constraint)

### Data Storage & Sync

- [ADR-0004: Sync Encryption and Multi-Device Support](adr-0004-sync-encryption.md) - **Proposed** (2025-12-20)
  - 24-word BIP39 recovery code for Master Key distribution across devices
  - Pull-based sync with Supabase Realtime notifications for instant updates
  - Last-write-wins conflict resolution (timestamp-based, KISS principle)
  - Offline-first: queue changes locally, sync when network available
  - Device management: audit trail and revocation
  - Zero-knowledge maintained: encrypted Master Key on server (recovery code never transmitted)

### Build & Test Infrastructure

- [ADR-0006: Test Coverage Requirements and Dual Threshold System](adr-0006-test-coverage-requirements.md) - **Accepted** (2025-12-28)
  - 90% overall project coverage minimum, 85% per-file minimum
  - Per-file exceptions for crypto code with unreachable defensive paths
  - Detailed mode (`--detailed`) for function-level coverage analysis
  - Security-critical code requires unit tests, failure cases, and edge case coverage

### UI/UX Architecture
<!-- Add ADRs related to SwiftUI patterns, navigation, accessibility -->

### Performance & Optimization
<!-- Add ADRs related to performance decisions, caching, memory management -->
