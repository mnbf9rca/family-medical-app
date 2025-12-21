# Research Directory

This directory contains research outputs for Phase 0 (Cryptographic Architecture Design).

## Issue #36: E2EE Sharing Patterns Research

### Main Document

**[e2ee-sharing-patterns-research.md](e2ee-sharing-patterns-research.md)** - Comprehensive research summary

This document covers:

- Signal Protocol & Double Ratchet analysis
- Symmetric key wrapping patterns
- Public-key encryption for sharing
- Hybrid approaches
- Real-world implementations (Bitwarden, 1Password, Standard Notes, ProtonMail)
- CryptoKit capabilities and limitations
- Comparison matrix and recommendations
- Public key exchange UX (TOFU approach)

### Proof-of-Concept Code

Three Swift proof-of-concept files demonstrating different sharing patterns:

1. **[poc-symmetric-key-wrapping.swift](poc-symmetric-key-wrapping.swift)**
   - Pattern: Wrap DEK with each user's master key
   - Pros: Simple, NIST-approved
   - Cons: Requires secure key exchange channel
   - Verdict: Good foundation, but incomplete

2. **[poc-public-key-sharing.swift](poc-public-key-sharing.swift)**
   - Pattern: Per-record sharing using Curve25519 ECDH
   - Pros: Works over insecure channels (email, QR code)
   - Cons: Storage overhead (N wrapped keys per record)
   - Verdict: Excellent for key distribution

3. **[poc-hybrid-family-keys.swift](poc-hybrid-family-keys.swift)** ⭐ **RECOMMENDED**
   - Pattern: Per-family-member keys with public-key sharing
   - Pros: Natural UX, efficient, scales well
   - Cons: Revocation requires re-encrypting ~100-500 records
   - Verdict: **Best fit for family medical app**

### Key Recommendation

**Use the Hybrid Per-Family-Member Key Model:**

- Each family member (patient) has a Family Member Key (FMK)
- All records for that patient are encrypted with their FMK
- FMK is wrapped separately for each authorized adult using ECDH
- Sharing flow: Email invitation with TOFU (Trust On First Use)
- Optional later verification via security codes

### Next Steps

This research informs the following ADRs:

- **ADR-0002:** Key Hierarchy (use Curve25519 + per-family-member FMKs)
- **ADR-0003:** Sharing Model (public-key encryption with TOFU)
- **ADR-0004:** Sync Encryption (encrypted blobs + wrapped FMK sync)
- **ADR-0005:** Access Revocation (re-encrypt with new FMK)

---

**Research completed:** 2025-12-19
**Status:** Ready for ADR authoring
