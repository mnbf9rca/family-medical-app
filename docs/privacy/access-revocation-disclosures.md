# Access Revocation: Privacy Policy and User Disclosures

This document provides ready-to-use privacy policy text and user disclosure wording for the access revocation mechanism. Copy-paste into your app's Privacy Policy and UI.

## Overview

The revocation mechanism includes **cryptographic remote erasure** but cannot guarantee deletion in all cases due to fundamental E2EE limitations.

## Core Privacy Principles

1. **Future access is cryptographically prevented**
2. **Historical data deletion is best-effort** (works if device is online and receives message)
3. **Users must be informed** before sharing that revocation has limitations
4. **Clear disclosure** of what works and what doesn't

## Required User Disclosures

### 1. Sharing Flow Disclosure

**When shown**: Before user shares medical records (sharing confirmation screen)

**Text**:

When you share medical records with another user, they will be able to download and view those records on their device.

If you later revoke their access:

- ✅ They cannot view NEW records or updates
- ✅ We will send a secure deletion request to their device
- ✅ If their device is online, cached records are cryptographically destroyed

However, we cannot guarantee deletion if:

- ⚠️ Their device is offline when you revoke access
- ⚠️ They backed up their device before revocation
- ⚠️ They are using a modified version of the app

Only share medical records with people you trust.

### 2. Revocation Flow Disclosure

**When shown**: When user initiates revocation (revocation confirmation dialog)

**Text**:

This will:

- ✅ Block [User] from NEW records
- ✅ Send secure deletion to their device
- ✅ Cryptographically destroy cached data (if device online)

This will re-encrypt [N] records (~2 seconds)

Cannot guarantee deletion if their device is offline or backed up.

### 3. Ownership Transfer Disclosure

**When shown**: During ownership transfer flow (both parties see this)

**Text**:

When you transfer ownership of medical records to [Name], you will retain access to records created before the transfer date. This is a permanent snapshot that cannot be revoked.

If [Name] later revokes your access, you will not be able to view new records created after the transfer.

### 4. Metadata Exposure Disclosure

**When shown**: Privacy Policy, first-time setup flow

**Text**:

While your medical records are end-to-end encrypted (we cannot read them), our servers can see:

- The accounts you shared records with (social graph), but not the names of those people
- When records were created/updated (timestamps)
- How many records you have (count and total size)
- When you access the app (login times)

We cannot see:

- Medical record content (encrypted)
- Share group member names (encrypted)
- Your encryption keys (stored only on your devices)
- Record types or categories (encrypted)

## Privacy Policy Sections

### Data Protection (How We Protect Your Data)

Your medical records are protected with end-to-end encryption. This means:

- Your data is encrypted on your device before being sent to our servers
- Our servers store only encrypted data (we cannot read it)
- Only people you explicitly share with can decrypt your records
- Even if our servers are breached, your data remains encrypted

Technical details: We use AES-256-GCM encryption with keys derived from your password using PBKDF2 (100,000 iterations). Your encryption keys never leave your device unencrypted.

### Access Control (Sharing and Revocation)

When you share medical records:

- You control who has access (granular per-family-member sharing)
- Shared users can download and decrypt records on their devices
- You can revoke access at any time

When you revoke access:

- Revoked user cannot access NEW records
- We send a secure deletion request to their device
- If their device is online, cached records are cryptographically destroyed
- Cannot guarantee deletion for offline devices, backups, or if they extracted encryption keys before revocation

We prioritize privacy over remote control: the same encryption that protects your data from server breaches also limits our ability to remotely delete data from devices.

### User Rights

```
You have the right to:
- Export your data (JSON, PDF, CSV formats)
- Delete your account (removes all data from our servers)
- Revoke access from shared users (prevents future access)
- View audit log (see who accessed your records and when)

Note: Deleting your account removes data from our servers, but users
you previously shared with may retain copies on their devices.
```

## Compliance

### GDPR

**Article 17 (Right to be Forgotten)**:

- Server-side deletion: ✅ Supported
- Device-side deletion: ⚠️ Best-effort via cryptographic erasure
- Required disclosure: "We will delete all your data from our servers, but other users who you previously shared with may retain copies of shared records on their devices."

**Article 20 (Data Portability)**: Export in JSON, PDF, CSV formats ✅

**Article 7 (Consent)**: Explicit consent required for sharing; withdrawal via revocation ✅

### HIPAA (if applicable)

**PHI Protection**: Encryption at rest and in transit ✅

**Revocation Limitations**: HIPAA allows retention of legitimately accessed PHI. Our app applies same principle.

**Required Disclosure**: "Healthcare providers who received your medical records before revocation may retain copies per HIPAA record retention requirements"

## FAQ

**Q: How does secure deletion work?**

A: When you revoke access, we send a cryptographic deletion request to the revoked user's device. If their device is online, it:

1. Re-encrypts all cached medical records with a random key
2. Immediately discards that random key (never stores it)
3. Result: Cached data becomes permanently undecryptable

This works in most typical cases (custody changes, relationship changes, device theft). It won't work if their device is offline, they backed up their device, or they extracted encryption keys beforehand.

---

**Q: Is this a security flaw?**

A: Our cryptographic deletion mechanism provides strong protection in most cases. The failures occur in edge cases:

- Device offline when revocation happens
- Device backed up before revocation (can restore from backup)
- Sophisticated attacker extracts keys prophylactically

These edge cases are inherent to end-to-end encryption. The alternative would be server-side encryption, where the server can guarantee deletion - but this would also mean the server (and anyone who breaches it) can read your medical records. We prioritize privacy over guaranteed remote control.

---

**Q: What should I do if I shared with someone I no longer trust?**

A:

1. Revoke their access immediately
   - Prevents future access to new records
   - Triggers secure deletion on their device (if device is online)
2. If highly sensitive records were shared, assume they may have a copy
3. For critical situations (abuse, stalking), contact support for guidance
4. Going forward, only share with people you trust

---

**Q: Does this comply with GDPR's "Right to be Forgotten"?**

A: Yes. GDPR allows for technical limitations where erasure is impossible or disproportionately difficult. We disclose this limitation clearly to users before sharing. Additionally, the "Right to be Forgotten" applies to the data controller (us), not to recipients with whom users voluntarily shared data.

---

**Q: What about HIPAA?**

A: HIPAA allows healthcare providers to retain PHI they legitimately accessed. Our app applies the same principle: users who legitimately had access can retain historical data. We provide cryptographic enforcement for future data (which exceeds HIPAA's minimum requirements).

## Implementation Checklist

**Phase 3 (Before Launch)**:

- [ ] Add sharing flow disclosure to UI
- [ ] Add revocation flow disclosure to confirmation dialog
- [ ] Create Privacy Policy with sections above
- [ ] Implement audit log with export capability
- [ ] Implement data export (JSON, PDF, CSV)
- [ ] Implement account deletion

**Phase 4 (Enhanced Revocation)**:

- [ ] Update disclosures with cryptographic erasure language
- [ ] Add FAQ section to support site
- [ ] Legal review of all privacy disclosures

**If Targeting EU Users**:

- [ ] GDPR compliance review
- [ ] Cookie consent (if applicable)
- [ ] Data processing agreement

**If Targeting Healthcare Use**:

- [ ] HIPAA compliance review
- [ ] Business Associate Agreements with vendors
- [ ] Audit trail retention policy

## Related Documents

- ADR-0005: Access Revocation and Cryptographic Key Rotation
- `/docs/technical/access-revocation-implementation.md` - Implementation guide
- `/docs/security/access-revocation-threat-analysis.md` - Threat model

---

**Last Updated**: 2025-12-22
**Related ADR**: ADR-0005
