# Periodic Key Rotation: Design Decision

## Decision

**No periodic key rotation for user identity keys or Family Member Keys (FMKs).**

Keys are rotated on-demand when compromise is detected or suspected.

## Rationale

### Medical Records Are Archives

Medical records are long-term archives, not ephemeral communications. A user logging in after 2 years must be able to read their historical allergy records.

| Type | Example | Lifetime | Access Pattern |
|------|---------|----------|----------------|
| **Communications** | Signal messages | Hours/days | User accepts data loss if device lost |
| **Archives** | Medical records, password vaults | Years/decades | Must remain accessible indefinitely |

This is the same model as password managers (1Password, Bitwarden) - no automatic rotation.

### NIST Guidance on Periodic Rotation (2024 Update)

**For user passwords**, NIST now recommends against periodic rotation:

> "Verifiers SHALL NOT require subscribers to change passwords periodically. However, verifiers SHALL force a change if there is evidence that the authenticator has been compromised."
>
> — [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html)

**Rationale**: [Mandatory periodic changes lead to weaker credentials](https://www.darkreading.com/identity-access-management-security/nist-drops-password-complexity-mandatory-reset-rules) - users make minor modifications instead of strong new passwords.

**For machine credentials and encryption keys**, the guidance is more nuanced:

- Periodic rotation is recommended for high-risk environments [with mature automation](https://nhimg.org/the-ultimate-guide-to-key-rotation-best-practices)
- [Without automation, frequent rotation is risky](https://blog.realkinetic.com/security-by-happenstance-afa191ec265d) - increases downtime and operational errors
- Event-driven rotation (on compromise) is acceptable for lower-risk scenarios

**Our assessment**: Family medical records are lower-risk (not financial transactions, not enterprise secrets). Event-driven rotation is appropriate.

### FMKs Are Like Long-Lived Refresh Tokens

Access patterns similar to OAuth refresh tokens:

| Type | Lifetime | Rotation | Purpose |
|------|----------|----------|---------|
| **Access Token** | Hours/days | Frequent | Short-term operations |
| **Refresh Token** | Months/years | On compromise | Generate new access tokens |
| **FMKs** | Years | On compromise | Long-term archive access |

### Periodic Rotation Doesn't Provide Forward Secrecy

If we rotated keys periodically:

**Year 1 rotation:**

1. Generate new FMK_v2
2. **Re-encrypt ALL records** from FMK_v1 → FMK_v2
3. Distribute wrapped FMK_v2 to all authorized users

**Year 3 (compromise):**

- Attacker gets user's private key
- Attacker downloads wrapped FMK_v2
- Attacker decrypts ALL records (including Year 0 records now encrypted with FMK_v2)
- **No forward secrecy** - old data accessible with current key

**To achieve forward secrecy** would require:

- Don't re-encrypt old records
- Maintain multiple FMK versions per family member
- Significant complexity with no clear benefit for medical records

### No Mature Automation Infrastructure

According to [security analysis by Real Kinetic](https://blog.realkinetic.com/security-by-happenstance-afa191ec265d):

> "Without mature practices and automation, rotating these keys frequently is an inherently risky operation that opens up the opportunity for downtime."

**Our context**:

- Hobby app scope
- No dedicated KMS infrastructure
- Manual processes increase risk of breaking emergency access
- Better to rely on event-driven rotation when needed

## Event-Driven Rotation (Current Design)

**Already implemented in ADR-0005:**

### When User Reports Device Compromised

1. Generate new FMK for affected family members
2. Re-encrypt all records (~500ms for 500 records)
3. Re-wrap new FMK for authorized devices (exclude compromised device)
4. **Result**: Compromised device locked out

**When**: User-initiated (like 1Password master password change)

**Why**: Respond to actual threats, not hypothetical schedules

## Trade-offs Accepted

| Risk | Mitigation |
|------|------------|
| **Key compromise → historical data accessible** | iOS Keychain security (Secure Enclave), event-driven rotation on detection |
| **No forward secrecy** | Correct trade-off for archives (emergency access > forward secrecy) |
| **Undetected compromise** | Same risk as password managers (industry-standard approach) |

## Comparison to Signal

Signal rotates keys with every message (Double Ratchet). If you lose your device:

1. Install Signal on new phone
2. All old messages are permanently gone (can't decrypt)
3. Start fresh

**This is correct for messaging, incorrect for medical records.**

Signal prioritizes forward secrecy over message history. Medical records prioritize long-term access over forward secrecy.

## Summary

**Three types of key updates:**

| Type | When | Status |
|------|------|--------|
| **Periodic** (scheduled) | Every N months | ❌ Not implemented |
| **Event-driven** (on-demand) | Device compromised, user revoked | ✅ Implemented (ADR-0005) |
| **Primary password change** | User changes password | ✅ Implemented (ADR-0002) |

## Related

- **ADR-0002**: Key Hierarchy (documents this decision)
- **ADR-0005**: Access Revocation (event-driven rotation implementation)
- **Issue #50**: Design periodic key rotation strategy

## References

### NIST Guidance

- [NIST SP 800-63B: Digital Identity Guidelines](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [NIST Password Guidelines 2025 Update](https://www.strongdm.com/blog/nist-password-guidelines)
- [NIST Drops Password Complexity, Mandatory Reset Rules](https://www.darkreading.com/identity-access-management-security/nist-drops-password-complexity-mandatory-reset-rules)

### Key Rotation Best Practices

- [Security by Happenstance: Key Rotation Risks](https://blog.realkinetic.com/security-by-happenstance-afa191ec265d)
- [Ultimate Guide to Key Rotation Best Practices](https://nhimg.org/the-ultimate-guide-to-key-rotation-best-practices)
- [Password Rotation Best Practices](https://www.beyondtrust.com/resources/glossary/password-rotation)
- [PCI DSS Key Rotation Requirements](https://pcidssguide.com/pci-dss-key-rotation-requirements/)

### Industry Examples

- [1Password: Secret Key Security](https://support.1password.com/secret-key-security/) - No automatic rotation
- [Signal Protocol: Double Ratchet](https://signal.org/docs/specifications/doubleratchet/) - Per-message rotation (different use case)

---

**Date**: 2025-12-23
**Status**: Approved
