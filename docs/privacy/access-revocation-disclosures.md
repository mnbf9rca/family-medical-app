# Access Revocation: Privacy Policy and User Disclosures

This document outlines the privacy implications of the access revocation mechanism and required user disclosures.

## Overview

The access revocation mechanism uses full FMK re-encryption to cryptographically prevent revoked users from decrypting new records. However, there are fundamental limitations due to the nature of end-to-end encryption that must be disclosed to users.

## Required User Disclosures

### 1. Historical Data Retention After Revocation

**Privacy Notice** (displayed during sharing setup):

```
When you share medical records with another user, they will be able
to download and view those records on their device. If you later revoke
their access, they will not be able to view NEW records or updates, but
they may retain access to records they downloaded before revocation.

This is a fundamental limitation of end-to-end encryption: once data is
decrypted on someone's device, we cannot remotely delete it.
```

**Disclosure Timing**:

- Initial sharing flow (when granting access)
- Revocation flow (reminder when revoking)
- Privacy Policy (legal document)

### 2. Ownership Transfer Snapshot

**Privacy Notice** (displayed during ownership transfer):

```
When you transfer ownership of medical records to [Child Name], you
will retain access to records created before the transfer date. This
is a permanent snapshot that cannot be revoked.

If [Child Name] later revokes your access, you will not be able to
view new records created after the transfer.
```

**Disclosure Timing**:

- Ownership transfer flow (both parent and child see this)
- Transfer confirmation screen
- Privacy Policy

### 3. Audit Trail Collection

**Privacy Notice**:

```
We maintain an encrypted audit log of who accessed your medical records
and when access was granted or revoked. This log is encrypted with your
Master Key and can only be viewed by you.

Audit logs are retained for [1 year / indefinitely / user-configurable]
and can be exported for legal or compliance purposes.
```

**Disclosure Timing**:

- Privacy Policy
- Settings > Privacy & Security > Audit Log

### 4. Server Metadata Exposure

**Privacy Notice**:

```
While your medical records are end-to-end encrypted (we cannot read
them), our servers can see:
- Who you shared records with (social graph)
- When records were created/updated (timestamps)
- How many records you have (count and total size)
- When you access the app (login times)

We cannot see:
- Medical record content (encrypted)
- Family member names (encrypted)
- Your encryption keys (stored only on your devices)
- Record types or categories (encrypted)
```

**Disclosure Timing**:

- Privacy Policy
- First-time setup flow

## GDPR Compliance Considerations

### Right to be Forgotten (Article 17)

**Server-side**: User can request deletion of all data from server (encrypted blobs deleted) ✅

**Limitation**: Cannot delete data from other users' devices (e.g., revoked user's cached records) ⚠️

**Required Disclosure**:

```
"We will delete all your data from our servers, but other users who you
previously shared with may retain copies of shared records on their devices."
```

### Data Portability (Article 20)

**Export functionality**: User can export medical records (JSON, PDF, CSV) ✅
**Audit log export**: User can export audit trail (encrypted or plaintext) ✅
**Key export**: User can export recovery code (for migration to other device) ✅

### Data Minimization (Article 5)

**Plaintext metadata**: Only expose what's necessary for sync coordination

- Record IDs (required for routing) ✅
- Timestamps (required for last-write-wins) ✅
- User IDs (required for access control) ✅

**Encrypted everything else**: Content, filenames, MIME types, family member names ✅

### Consent (Article 7)

**Explicit consent** required for:

- Creating account (Master Key derivation from password)
- Sharing records with other users (ECDH key wrapping)
- Transferring ownership (child gains independent control)

**Withdrawal of consent**: Revocation mechanism (this ADR) enables withdrawal ✅

## HIPAA Compliance Considerations (if applicable)

### Personal Health Information (PHI) Protection

- **Encryption at rest**: All medical records encrypted with AES-256-GCM ✅
- **Encryption in transit**: HTTPS/TLS for all server communication ✅
- **Access controls**: Server-side access grants enforce authorization ✅
- **Audit trail**: All access/revocation events logged (encrypted) ✅

### Business Associate Agreement (BAA)

- **Server provider**: If using Supabase/AWS, must sign BAA (they are Business Associate)
- **Zero-knowledge architecture**: Even with BAA, server cannot access PHI (encrypted)

### Revocation Limitations

**HIPAA allows**: PHI that was legitimately accessed before revocation can be retained

**Required Disclosure**:

```
"Healthcare providers who received your medical records before revocation
may retain copies per HIPAA record retention requirements"
```

**Our app**: Same principle applies to family members (legitimate access before revocation)

## Recommended Privacy Policy Sections

### Section 1: How We Protect Your Data

```
Your medical records are protected with end-to-end encryption. This means:
- Your data is encrypted on your device before being sent to our servers
- Our servers store only encrypted data (we cannot read it)
- Only people you explicitly share with can decrypt your records
- Even if our servers are breached, your data remains encrypted

Technical details: We use AES-256-GCM encryption with keys derived from
your password using PBKDF2 (100,000 iterations). Your encryption keys
never leave your device unencrypted.
```

### Section 2: Sharing and Access Control

```
When you share medical records:
- You control who has access (granular per-family-member sharing)
- Shared users can download and decrypt records on their devices
- You can revoke access at any time (prevents future access)
- Revoked users may retain records they downloaded before revocation

This limitation is fundamental to end-to-end encryption: once someone
decrypts data on their device, we cannot remotely delete it.
```

### Section 3: What We Can and Cannot See

```
We can see (metadata):
- Who you shared records with
- When you access the app
- How many records you have
- File sizes

We cannot see (encrypted):
- Medical record content
- Family member names
- Your encryption keys
- Record types or categories
```

### Section 4: Your Rights

```
You have the right to:
- Export your data (JSON, PDF, CSV formats)
- Delete your account (removes all data from our servers)
- Revoke access from shared users (prevents future access)
- View audit log (see who accessed your records and when)

Note: Deleting your account removes data from our servers, but users
you previously shared with may retain copies on their devices.
```

## UI Disclosure Examples

### Sharing Flow

```
┌─────────────────────────────────────────┐
│ Share Emma's Records with Adult B       │
├─────────────────────────────────────────┤
│                                          │
│ ⚠️ Important: Understand Access Control │
│                                          │
│ When you share records, Adult B will:   │
│ ✅ Download encrypted records            │
│ ✅ Decrypt them on their device          │
│ ✅ View them even when offline           │
│                                          │
│ If you later revoke access:             │
│ ✅ Adult B can't access NEW records      │
│ ⚠️ Adult B keeps OLD records (cached)   │
│                                          │
│ This is a fundamental limit of E2EE.    │
│ Only share with people you trust.       │
│                                          │
│ [Cancel] [I Understand, Share]          │
└─────────────────────────────────────────┘
```

### Revocation Flow

```
┌─────────────────────────────────────────┐
│ Revoke Adult C's Access to Emma?        │
├─────────────────────────────────────────┤
│                                          │
│ ✅ Adult C can't decrypt NEW records     │
│ ✅ Adult C can't download updates        │
│ ⚠️ Adult C keeps records they downloaded│
│                                          │
│ This will re-encrypt 500 records        │
│ (~2 seconds)                            │
│                                          │
│ [Cancel] [Revoke Access]                │
└─────────────────────────────────────────┘
```

### Ownership Transfer Flow

```
┌─────────────────────────────────────────┐
│ Transfer Emma's Records to Emma?        │
├─────────────────────────────────────────┤
│                                          │
│ ⚠️ Important: Permanent Snapshot         │
│                                          │
│ You will retain access to:              │
│ ✅ All records created before transfer   │
│                                          │
│ Emma can later revoke your access:      │
│ ✅ You won't see NEW records             │
│ ⚠️ You keep OLD records (permanent)     │
│                                          │
│ This cannot be undone. Emma will have   │
│ full control and can revoke your access.│
│                                          │
│ [Cancel] [Transfer Ownership]           │
└─────────────────────────────────────────┘
```

## Implementation Checklist

- [ ] Add privacy notices to sharing flow UI (Phase 3)
- [ ] Add privacy notices to revocation flow UI (Phase 3)
- [ ] Add privacy notices to ownership transfer flow UI (Phase 4)
- [ ] Create comprehensive Privacy Policy document (Phase 3)
- [ ] Add "Privacy & Security" section to Settings (Phase 3)
- [ ] Implement audit log export (Phase 3)
- [ ] Implement data export (Phase 3)
- [ ] Implement account deletion (Phase 3)
- [ ] GDPR compliance review (Phase 3, if serving EU users)
- [ ] HIPAA compliance review (Phase 4, if targeting healthcare use)
- [ ] Legal review of privacy disclosures (before public release)

## Frequently Asked Questions

### Q: Why can't you remotely delete data from revoked users?

**A**: End-to-end encryption means data is decrypted on the user's device, not on our servers. Once decrypted, the data exists in plaintext on their device. We have no technical ability to remotely access or delete files from their device. This is the same limitation faced by Signal, WhatsApp, and all E2EE systems.

### Q: Is this a security flaw?

**A**: No, this is a fundamental property of end-to-end encryption. The alternative would be server-side encryption, where the server can decrypt data and thus enforce remote deletion - but this would also mean the server (and anyone who breaches it) can read your medical records. We prioritize privacy over remote control.

### Q: What should I do if I shared with someone I no longer trust?

**A**:

1. Revoke their access immediately (prevents future access)
2. Understand they retain historical data they downloaded
3. For critical situations, contact support for guidance
4. Going forward, only share with people you trust long-term

### Q: Does this comply with GDPR's "Right to be Forgotten"?

**A**: Yes. GDPR allows for technical limitations where erasure is impossible or disproportionately difficult. We disclose this limitation clearly to users before sharing. Additionally, the "Right to be Forgotten" applies to the data controller (us), not to recipients with whom users voluntarily shared data.

### Q: What about HIPAA?

**A**: HIPAA allows healthcare providers to retain PHI they legitimately accessed. Our app applies the same principle: users who legitimately had access can retain historical data. We provide cryptographic enforcement for future data (which exceeds HIPAA's minimum requirements).

## Related Documents

- ADR-0005: Access Revocation and Cryptographic Key Rotation
- `/docs/technical/access-revocation-implementation.md` - Implementation guide
- `/docs/security/access-revocation-threat-analysis.md` - Threat model

---

**Last Updated**: 2025-12-22
**Related ADR**: ADR-0005
