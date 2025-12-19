# Cryptographic Architecture Must Be Designed Before Implementation

## Status

**Status**: accepted

**Date**: 2025-12-19

## Context

During initial planning, we began evaluating local encrypted storage options (Core Data vs SQLCipher vs Realm) for Phase 1 implementation. However, this revealed a critical architectural dependency: **the choice of local storage technology is downstream from the cryptographic architecture design**.

The application requires:
1. **End-to-end encrypted sharing** between family members
2. **Zero-knowledge sync** to backend server
3. **Cryptographic access revocation** when permissions change
4. **Multi-user decryption** (multiple family members can decrypt same child's record)
5. **Age-based access control** with ownership transfer

These requirements demand design decisions about:
- **Key hierarchy**: How user password → master key → data keys → sharing keys
- **Sharing model**: Symmetric key wrapping vs public-key encryption vs hybrid
- **Key distribution**: How authorized users receive decryption keys
- **Access revocation**: Key rotation, re-encryption, or other mechanisms
- **Sync encryption**: How to package encrypted data for server storage
- **Metadata encryption**: What can remain plaintext for sync efficiency

Without these design decisions, we risk:
1. **Implementation rework**: Building local storage that doesn't support the sharing model
2. **Security vulnerabilities**: Making incorrect assumptions about key management
3. **Performance issues**: Choosing encryption granularity incompatible with sync
4. **Migration complexity**: Needing to re-encrypt all data when sharing is added

## Decision

**The complete cryptographic architecture must be designed before any implementation begins.**

Specifically:
1. **Phase 0 (new)**: Design cryptographic architecture
   - Key hierarchy and derivation
   - Sharing model (how multiple users decrypt same data)
   - Sync encryption (blob packaging, metadata handling)
   - Access revocation mechanism
   - Document all decisions in ADRs

2. **Phase 1**: Implement local-only foundation *after* Phase 0 complete
   - Local storage choice informed by crypto architecture
   - Key management implemented according to designed hierarchy
   - Data model structured to support future sharing

3. **Phase 2+**: Sync and sharing implementations follow Phase 0 design

This establishes **"crypto-first architecture"** as a core principle:
- Cryptographic requirements drive implementation decisions
- Security design precedes feature implementation
- No "add encryption later" approaches

## Consequences

### Positive

1. **Correct implementation from start**: Local storage structured to support sharing model
2. **Security by design**: Cryptographic decisions reviewed before code written
3. **Avoid rework**: No need to re-architect storage when adding sync/sharing
4. **Clear dependencies**: Phases have explicit prerequisites
5. **Better documentation**: Crypto architecture decisions captured in ADRs before implementation obscures them
6. **Easier security audit**: Architecture documented and reviewable before implementation complexity

### Negative

1. **Delayed implementation start**: Must complete crypto design before writing code
2. **Requires deep crypto knowledge upfront**: Need to understand sharing models, key rotation, etc. before building anything
3. **Risk of over-design**: Might design features we won't need (but YAGNI principle mitigates this)
4. **Longer planning phase**: More time in "no visible progress" stage

### Neutral

1. **Changes project timeline**: Adds explicit Phase 0, but prevents later rework
2. **Requires additional research**: Need to research E2EE sharing patterns (Signal Protocol, etc.)
3. **More ADRs needed**: Each crypto decision gets its own ADR

## Related Decisions

- **ADR-0002** (future): Key hierarchy design
- **ADR-0003** (future): Sharing model (symmetric wrapping vs public-key)
- **ADR-0004** (future): Sync encryption blob format
- **ADR-0005** (future): Access revocation mechanism

## References

- Issue #2: Research local encrypted storage options
- AGENTS.md: Cryptographic specifications (AES-256-GCM, CryptoKit, KDF requirements)
- README.md: Architecture Overview (updated to reflect crypto-first approach)

## Implementation Notes

When designing the cryptographic architecture, we must research:
1. **Signal Protocol**: Double Ratchet for forward secrecy (may be overkill for our use case)
2. **Key wrapping patterns**: How to share symmetric keys securely
3. **Public-key sharing**: Each user has keypair, encrypt data keys with recipient's public key
4. **Hybrid approaches**: Per-family-member symmetric keys + key wrapping
5. **Key rotation**: Strategies for updating keys without data loss or downtime
6. **Tombstoning**: How to cryptographically prove access was revoked

The design must balance:
- **Security**: No server access to plaintext, cryptographic access revocation
- **Performance**: Efficient for small dataset (< 1000 records), works offline
- **Complexity**: Keep It Simple - don't over-engineer for theoretical attacks
- **Maintainability**: Auditable crypto code, no custom implementations (CryptoKit only)
