# Access Revocation and Cryptographic Key Rotation

## Status

**Status**: Accepted

## Context

The Family Medical App must support **cryptographic access revocation** - the ability to permanently remove a user's access to medical records, even if they've already downloaded encrypted data. This is critical for:

- **Custody disputes**: Adult loses custody, must lose access to records
- **Trust violations**: Previously authorized user becomes malicious
- **Device theft**: Compromised device must be locked out
- **Age-based control**: Individual reaches age of majority, revokes access

### The Core Problem

UI-level permission removal is insufficient:

```
Naive approach (UI-only):
├─ Delete access grant from database
├─ Revoked user can't download NEW records ✅
└─ Revoked user still has FMK cached locally ❌
    └─ Can decrypt all records (even new ones if downloaded)
```

This violates the cryptographic enforcement requirement: revoked users must be **unable** to decrypt records, not just prevented from accessing them in the UI.

### Foundation

This ADR builds on:

- **ADR-0002**: Key Hierarchy → Per-family-member FMKs
- **ADR-0003**: Multi-User Sharing Model → ECDH-wrapped FMKs
- **ADR-0004**: Sync Encryption → Realtime propagation, offline handling

## Decision

We will implement **full re-encryption with new Family Member Key (FMK)** for cryptographic access revocation.

### Core Mechanism

When Adult A revokes Adult C's access to Emma's records:

1. **Generate new FMK**: `FMK_Emma_v2` (random 256-bit key)
2. **Re-encrypt all records**: Decrypt with `FMK_v1`, re-encrypt with `FMK_v2`
3. **Re-wrap for authorized users**: Wrap `FMK_v2` for Adult A and Adult B (exclude Adult C)
4. **Sync across devices**: Realtime notification to all devices
5. **Result**: Adult C cannot decrypt new records (only has old `FMK_v1`)

### Key Design Decisions

#### 1. Full Re-encryption (not key versioning)

**Decision**: Re-encrypt all records immediately, single active FMK per family member.

**Rationale**:

- ✅ **True revocation**: Old FMK becomes useless for new data
- ✅ **Clean architecture**: No key version tracking
- ✅ **Performance**: ~500ms for 500 records (acceptable)
- ⚠️ **Trade-off**: Re-encryption cost vs. true cryptographic enforcement

**Alternative rejected**: Keep `FMK_v1` for old records, `FMK_v2` for new → Partial revocation only

#### 2. Atomic Revocation (transaction-based)

**Decision**: All-or-nothing re-encryption using database transactions.

**Rationale**: Prevents partial revocation (some records with old FMK, some with new)

#### 3. Realtime Propagation

**Decision**: Use Realtime notifications for immediate cross-device sync.

**Rationale**:

- ✅ **Immediate**: Revocation propagates in seconds
- ✅ **Self-healing**: Offline devices detect version mismatch on next sync

#### 4. Historical Data Limitation (Mitigated)

**Decision**: Revoked user retains access to records downloaded before revocation, **unless** their device receives a cryptographic remote erasure message.

**Rationale**:

- ⚠️ **Fundamental E2EE limitation**: Cannot guarantee deletion (offline devices, backups, etc.)
- ✅ **Best-effort mitigation**: Cryptographic remote erasure (works in most typical scenarios)
- ✅ **Opportunistic**: Works when device is online and receives Realtime notification
- ✅ **Offline-first preserved**: Deletion is opportunistic, not required for revocation

**Cryptographic Remote Erasure** (Phase 4 enhancement):

- Send Realtime notification to revoked user's devices
- Re-encrypt cached records with random ephemeral key
- Immediately discard the key (data becomes permanently undecryptable)
- Success depends on timing: works if device online and receives message before key extraction
- Works in most typical scenarios when device is online

### Special Cases

#### Ownership Transfer (Age-Based Access Control)

When an individual reaches age of majority and gains control (or when transferring records for a vulnerable adult):

1. New owner creates independent account (own Master Key, separate from previous owner)
2. Previous owner grants new owner access (standard ECDH sharing)
3. New owner becomes owner (re-wraps FMK with own Master Key)
4. New owner can revoke previous owner (standard revocation flow) - or can choose to continue granting access to previously authorized users

Note: The app will not automatically trigger or enforce age-based ownership transfers. The app may suggest ownership transfer at certain milestones, or require periodic access reviews and reconsent, but will never force a transfer. This respects diverse family situations including vulnerable adults, guardianship arrangements, court orders, and other circumstances where ongoing access is appropriate.

**Trade-off**: Previous owner retains snapshot of pre-transfer records (cannot be avoided).

**Disclosure**: Clearly communicate to both parties during transfer.

### Performance

**Benchmarks** (goals):

- 100 records: ~100ms
- 500 records: ~500ms
- 1000 records: ~1s

**UX**: Show progress bar, user-initiated action (acceptable 2-3 second delay).

## Consequences

### Positive

1. **True Cryptographic Revocation**: Revoked users cannot decrypt new records (not just UI hiding)
2. **Granular Control**: Revoke per family member (Emma not Liam)
3. **Immediate Propagation**: Realtime across all devices (seconds)
4. **Offline-Resilient**: Devices self-heal via version mismatch detection
5. **Clean Architecture**: Single active FMK (no version tracking complexity)
6. **Audit Trail**: All revocation events logged (encrypted)
7. **Industry-Standard**: Comparable to 1Password, Signal revocation models

### Negative

1. **Historical Data Accessible**: Revoked user may retain pre-revocation records
   - **Severity**: Medium (fundamental E2EE limitation)
   - **Mitigation**: Cryptographic remote erasure (works in most typical scenarios), clear disclosure
   - **Accepted**: Cannot guarantee deletion (offline devices, backups, key extraction)

2. **Re-encryption Cost**: ~500ms for 500 records
   - **Severity**: Low (user-initiated, infrequent)
   - **Mitigation**: Progress bar, batch processing
   - **Accepted**: Performance cost for true revocation

3. **Network Dependency**: Requires online device to re-encrypt
   - **Severity**: Medium (offline device cannot revoke)
   - **Mitigation**: Queue for later, process when online
   - **Accepted**: Consistent with async architecture (ADR-0003/0004)

4. **Transaction Complexity**: Server-side atomic operations required
   - **Severity**: Medium (implementation complexity)
   - **Mitigation**: Supabase/PostgreSQL native support
   - **Accepted**: Reliability requires transactions

### Neutral

1. **Re-granting creates fresh state**: Re-granted user sees only current data (not historical versions)
   - **Note**: Privacy-enhancing (clean slate)

2. **Server sees revocation metadata**: Social graph exposed (who revoked whom)
   - **Note**: Consistent with zero-knowledge content encryption (ADR-0003)

### Trade-offs Accepted

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **Full Re-encryption** | ~500ms performance cost | True cryptographic revocation (not UI-only) |
| **Realtime Propagation** | Requires Supabase Realtime | Immediate revocation across devices |
| **Atomic Revocation** | Transaction complexity | Data integrity (prevent partial state) |
| **Historical Data Accessible** | Best-effort deletion (works if device online) | Opportunistic cryptographic erasure, can't guarantee (offline/backups) |

## Implementation Notes

### Phase 3: Group Sharing (Required)

Implement:

- Revocation UI (Settings > Manage Access)
- Re-encryption engine (FMK rotation)
- Atomic transaction flow
- Realtime sync propagation
- Audit trail (encrypted log)

### Phase 4: Enhancements (Recommended)

- **Cryptographic Remote Erasure** (high priority):
  - Send Realtime secure deletion message on revocation
  - Re-encrypt cached records with ephemeral random key, discard key
  - Works in most typical scenarios when device is online
  - Opportunistic (doesn't break offline-first)
- **HMAC Signatures on Audit Entries** (tamper detection):
  - Add cryptographic signatures to audit log entries
  - Blockchain-style chaining prevents modification/deletion/reordering
  - See `docs/technical/audit-log-signatures.md` for complete design
  - Resolves Issue #47
- Background re-encryption (large datasets)
- Ownership transfer UI (age-based control)
- Export audit log (PDF for legal purposes)
- Log securely shared between all sharing participants so there's a single log

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes revocation requirement)
- **ADR-0002**: Key Hierarchy (defines FMKs, rotation strategy)
- **ADR-0003**: Multi-User Sharing Model (ECDH wrapping)
- **ADR-0004**: Sync Encryption (Realtime propagation, offline handling)

## References

### Design Documents

- Issue #40: ADR-0005 Access Revocation
- `docs/research/e2ee-sharing-patterns-research.md` (Section 9.2: Revocation analysis)

### Detailed Documentation

For implementation details, see:

- `/docs/technical/access-revocation-implementation.md` - Code examples, CryptoKit usage
- `/docs/technical/audit-log-signatures.md` - Audit log tamper detection (Phase 4)
- `/docs/security/access-revocation-threat-analysis.md` - Comprehensive threat model
- `/docs/privacy/access-revocation-disclosures.md` - Privacy policy implications, GDPR/HIPAA

### External References

- AGENTS.md: Cryptography specifications
- [NIST SP 800-57](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final): Key Management (Section 8.3.4: Key Revocation)
- [1Password: Access Revocation](https://support.1password.com/remove-team-member/)
- [Signal: Group Chat Revocation](https://signal.org/blog/group-chats/)

---

**Decision Date**: 2025-12-22
**Author**: Claude Code (based on ADR-0002, ADR-0003, ADR-0004)
**Reviewers**: [To be assigned]
