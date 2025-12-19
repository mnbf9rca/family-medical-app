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
  - PBKDF2-HMAC-SHA256 (100k iterations) for password derivation
  - Per-family-member data encryption keys for granular access control
  - ECDH-based key wrapping for sharing over insecure channels
  - Re-encryption strategy for cryptographic access revocation

### Data Storage & Sync
<!-- Add ADRs related to databases, sync protocols, conflict resolution -->

### Build & Test Infrastructure
<!-- Add ADRs related to CI/CD, testing strategy, build configuration -->

### UI/UX Architecture
<!-- Add ADRs related to SwiftUI patterns, navigation, accessibility -->

### Performance & Optimization
<!-- Add ADRs related to performance decisions, caching, memory management -->
