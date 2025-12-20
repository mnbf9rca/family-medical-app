# Privacy and Data Exposure Analysis

**Issue:** #38 (ADR-0003 Multi-User Sharing Model)
**Epic:** #35 (Phase 0 - Cryptographic Architecture Design)
**Date:** 2025-12-20
**Status:** Analysis Complete

## Executive Summary

This document provides a transparent analysis of **what data is exposed to whom** in the Family Medical App's cryptographic architecture, and the privacy benefits and trade-offs of our design decisions.

### Quick Assessment

**✅ Strong Privacy Properties:**
- Medical record **content** is end-to-end encrypted (server cannot read)
- Family Member Keys (FMKs) are wrapped with user-specific keys (server cannot decrypt)
- User passwords never transmitted to server
- Master keys stored device-only (never synced)

**⚠️ Metadata Exposure:**
- Server knows social graph (who shares with whom)
- Server knows which family members exist (pseudonymous IDs)
- Server knows usage patterns (login times, sync frequency)

**Trade-off Rationale:**
- Async operation requires server-side routing → Some metadata exposure unavoidable
- UX simplicity prioritized (email invitations vs. in-person QR codes)
- Threat model: Protect medical content from everyone, accept relationship metadata for convenience

---

## Table of Contents

1. [What the Server Can See](#1-what-the-server-can-see)
2. [What the Server Cannot See](#2-what-the-server-cannot-see)
3. [What Other Users Can See](#3-what-other-users-can-see)
4. [What Attackers Can See](#4-what-attackers-can-see)
5. [Threat Model Analysis](#5-threat-model-analysis)
6. [Privacy Benefits](#6-privacy-benefits)
7. [Metadata Leakage Deep Dive](#7-metadata-leakage-deep-dive)
8. [Comparison to Alternatives](#8-comparison-to-alternatives)
9. [Attack Scenarios and Mitigations](#9-attack-scenarios-and-mitigations)
10. [Privacy-Enhancing Roadmap](#10-privacy-enhancing-roadmap)

---

## 1. What the Server Can See

The server (Supabase or equivalent backend) has access to certain metadata required for routing and coordination.

### 1.1 User Identity Metadata

| Data | Visibility | Purpose | Sensitivity |
|------|-----------|---------|-------------|
| **User ID** (UUID) | ✅ Plaintext | Account management, routing | Low (pseudonymous) |
| **Email address** | ✅ Plaintext | Account recovery, invitations | Medium (PII) |
| **Display name** | ✅ Plaintext | UI display for sharing | Low (user-chosen) |
| **Public key** | ✅ Plaintext | Key exchange (public by design) | None (public) |
| **Password** | ❌ **Never transmitted** | Local authentication | N/A (client-only) |
| **Master Key** | ❌ **Never transmitted** | Local encryption | N/A (device-only) |
| **Private key** | ❌ **Never transmitted** | Stored encrypted in Keychain | N/A (client-only) |

**Example server view:**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "alice@example.com",
  "display_name": "Alice",
  "public_key": "MC4CAQAwBQ...",
  "created_at": "2025-01-15T10:30:00Z",
  "last_login": "2025-01-20T14:22:00Z"
}
```

**Privacy implications:**
- ✅ **Email is PII**: Server knows real identity (required for invitations)
- ✅ **Pseudonymous UUIDs**: Medical records linked to UUIDs, not directly to emails
- ⚠️ **Login timestamps**: Server knows when users access app

### 1.2 Family Member Metadata

| Data | Visibility | Purpose | Sensitivity |
|------|-----------|---------|-------------|
| **Family member ID** (UUID) | ✅ Plaintext | Record grouping | Low (pseudonymous) |
| **Family member name** | ❌ **Encrypted** | Encrypted with FMK | High (identity) |
| **Relationship type** | ⚠️ Optional plaintext | UI filtering (e.g., "child", "parent") | Low (categorical) |
| **Owner user ID** | ✅ Plaintext | Access control | Low (UUID link) |

**Example server view:**
```json
{
  "family_member_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "owner_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "relationship_type": "child",  // Optional plaintext metadata
  "created_at": "2025-01-15T10:35:00Z"
}
```

**Privacy implications:**
- ✅ **Names encrypted**: Server sees UUID "7c9e...ae7", not "Emma age 5"
- ⚠️ **Relationship type**: If included as plaintext metadata for filtering (e.g., "show only my children"), server knows family structure
- ⚠️ **Ownership**: Server knows "User 550e...000 created family member 7c9e...ae7"

**Design decision**: Whether `relationship_type` is encrypted depends on UX needs. If app has "Children" vs. "Parents" tabs, this must be plaintext for server-side filtering. If all filtering is client-side, it can be encrypted.

### 1.3 Sharing Relationship Metadata

| Data | Visibility | Purpose | Sensitivity |
|------|-----------|---------|-------------|
| **Inviter user ID** | ✅ Plaintext | Track who initiated sharing | Low (UUID) |
| **Invitee email** | ✅ Plaintext | Send invitation email | Medium (PII) |
| **Family member ID** | ✅ Plaintext | Identify what's being shared | Low (UUID) |
| **Invitation status** | ✅ Plaintext | Track pending/accepted/completed | Low (state) |
| **Access grant timestamp** | ✅ Plaintext | Audit trail | Low (timestamp) |
| **Wrapped FMK** | ❌ **Encrypted** | Key wrapping (opaque blob) | High (key material) |

**Example server view:**
```json
// Invitation table
{
  "invitation_id": "abc-123",
  "inviter_user_id": "550e8400-...",
  "invitee_email": "bob@example.com",
  "family_member_id": "7c9e6679-...",
  "status": "accepted",
  "created_at": "2025-01-15T11:00:00Z",
  "accepted_at": "2025-01-17T09:30:00Z"
}

// Access grant table
{
  "grant_id": "def-456",
  "family_member_id": "7c9e6679-...",
  "granted_to_user_id": "9b2e8400-...",
  "wrapped_fmk": "AgEAAHicY2BkYGBg...",  // Opaque encrypted blob
  "granter_public_key": "MC4CAQAwBQ...",
  "created_at": "2025-01-17T10:00:00Z"
}
```

**Privacy implications:**
- ✅ **Social graph visible**: Server knows "User 550e...000 shared family member 7c9e...ae7 with user 9b2e...000"
- ✅ **Wrapped FMK is opaque**: Server cannot decrypt (requires recipient's private key for ECDH)
- ⚠️ **Timing analysis**: Server knows when invitations sent/accepted (correlation possible)

**This is the primary metadata exposure point** - see [Section 7: Metadata Leakage](#7-metadata-leakage-deep-dive) for detailed analysis.

### 1.4 Medical Record Metadata

| Data | Visibility | Purpose | Sensitivity |
|------|-----------|---------|-------------|
| **Record ID** (UUID) | ✅ Plaintext | Record identification | Low (pseudonymous) |
| **Family member ID** | ✅ Plaintext | Group records by patient | Low (UUID) |
| **Record type** | ⚠️ Optional plaintext | Filtering (e.g., "vaccine", "allergy") | Medium (health category) |
| **Encrypted data blob** | ❌ **Encrypted** | Medical content (AES-256-GCM) | High (PHI) |
| **Timestamp** | ✅ Plaintext | Sync conflict resolution | Low (timestamp) |
| **Record size** | ✅ Plaintext | Network metadata | Low (size in bytes) |

**Example server view:**
```json
{
  "record_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "family_member_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "record_type": "vaccine",  // Optional plaintext for filtering
  "encrypted_data": "AQAAAACAAABZwg...",  // Opaque AES-GCM ciphertext
  "created_at": "2025-01-15T12:00:00Z",
  "updated_at": "2025-01-15T12:00:00Z",
  "size_bytes": 2048
}
```

**Privacy implications:**
- ✅ **Content encrypted**: Server sees ciphertext, cannot read "COVID vaccine 2023-05-15"
- ⚠️ **Record type**: If plaintext (e.g., for "show all vaccines" filter), server knows health categories
- ⚠️ **Record count**: Server knows "Family member 7c9e...ae7 has 15 vaccine records" (volume metadata)
- ⚠️ **Size analysis**: Large records might indicate scanned documents vs. short text notes

**Design decision**: Similar to relationship_type, whether `record_type` is plaintext depends on whether filtering happens server-side (plaintext) or client-side (encrypted).

### 1.5 Usage Metadata

| Data | Visibility | Purpose | Sensitivity |
|------|-----------|---------|-------------|
| **Login timestamps** | ✅ Plaintext | Session management | Low (usage patterns) |
| **Sync frequency** | ✅ Plaintext | Server logs | Low (technical) |
| **IP addresses** | ✅ Plaintext | Connection metadata | Medium (location proxy) |
| **Device type** | ⚠️ Optional | Analytics | Low (iOS version, etc.) |

**Privacy implications:**
- ⚠️ **IP addresses reveal location**: Server knows "User logged in from San Francisco"
- ⚠️ **Usage patterns**: "User checks app every day at 8am" (behavioral metadata)
- ⚠️ **Correlation risk**: If server logs are retained, can correlate users' activities

**Mitigation**: Data retention policy (delete logs after 30 days), anonymize IPs in analytics.

---

## 2. What the Server Cannot See

The cryptographic architecture ensures the server is **blind to actual medical content** and **key material**.

### 2.1 Medical Record Content

**Encrypted with AES-256-GCM using Family Member Key (FMK)**

| Data Type | Server Visibility | Client Visibility |
|-----------|------------------|-------------------|
| **Medical diagnoses** | ❌ Ciphertext only | ✅ Decrypted locally |
| **Medication names** | ❌ Ciphertext only | ✅ Decrypted locally |
| **Doctor notes** | ❌ Ciphertext only | ✅ Decrypted locally |
| **Vaccine dates** | ❌ Ciphertext only | ✅ Decrypted locally |
| **Allergies** | ❌ Ciphertext only | ✅ Decrypted locally |
| **Scanned documents** | ❌ Ciphertext only | ✅ Decrypted locally |

**Example:**
```
Plaintext (client-side only):
{
  "type": "vaccine",
  "name": "COVID-19 Pfizer",
  "date": "2023-05-15",
  "provider": "Dr. Smith, Family Clinic",
  "notes": "Second dose, no adverse reactions"
}

Ciphertext (server sees):
"AQAAAACAAABZwgEAAB0AAAAAAAAADwAAAGNvbS5hcHBsZS5zZWN1cmVkYXRh..."
```

**Why server can't decrypt:**
- FMK is random 256-bit key, never transmitted to server
- Server only has wrapped FMKs (encrypted with ECDH-derived keys)
- ECDH-derived keys require user's private key (device-only, in Keychain)

### 2.2 Cryptographic Keys

| Key Type | Server Visibility | Storage Location |
|----------|------------------|------------------|
| **User Master Key** | ❌ Never transmitted | iOS Keychain (device-only) |
| **User Private Key (Curve25519)** | ❌ Never transmitted | iOS Keychain (encrypted with Master Key) |
| **Family Member Keys (FMKs)** | ❌ Never transmitted (only wrapped versions) | iOS Keychain (owner), Core Data (wrapped for others) |
| **User Public Key** | ✅ Transmitted (public by design) | Server + Core Data |
| **ECDH Shared Secrets** | ❌ Never transmitted (ephemeral, derived locally) | Computed in memory, never stored |
| **HKDF Wrapping Keys** | ❌ Never transmitted (derived from shared secrets) | Computed in memory, never stored |

**Key derivation chain (all local):**
```
User Password (known only to user)
   ↓ PBKDF2 (100k iterations, local)
Master Key (Keychain, device-only)
   ↓ AES encryption (local)
Private Key (Keychain, encrypted)
   ↓ ECDH (local)
Shared Secret (ephemeral, in-memory)
   ↓ HKDF (local)
Wrapping Key (ephemeral, in-memory)
   ↓ AES.KeyWrap (local)
Wrapped FMK (uploaded to server as opaque blob)
```

**Server has NO access to any step except the final wrapped blob.**

### 2.3 User Passwords

| Data | Server Visibility | Why |
|------|------------------|-----|
| **User password** | ❌ Never transmitted | Used only for local key derivation |
| **Password hash** | ⚠️ Supabase stores (for authentication) | Supabase uses bcrypt, not accessible to app |
| **Derived Master Key** | ❌ Never transmitted | Stored in Keychain, device-only |

**Authentication flow:**
```
Traditional (NOT zero-knowledge):
├─ User enters password
├─ Supabase hashes with bcrypt (server-side)
└─ Supabase stores hash, validates login

Our app (local key derivation):
├─ User enters password
├─ App derives Master Key locally (PBKDF2)
├─ Master Key used to decrypt Private Key
└─ Master Key never sent to server

Server authentication:
├─ Supabase handles login (separate password hash)
└─ App never sees Supabase password hash
```

**Important**: We use Supabase's built-in auth (email/password), which stores a password hash. This is separate from the Master Key derivation. If we wanted true zero-knowledge auth, we'd need a different approach (e.g., SRP protocol), but that's beyond hobby app scope.

### 2.4 Family Member Names

| Data | Server Visibility | Encryption |
|------|------------------|-----------|
| **Family member name** | ❌ Encrypted with FMK | AES-256-GCM |
| **Date of birth** | ❌ Encrypted with FMK | AES-256-GCM |
| **Photo** | ❌ Encrypted with FMK | AES-256-GCM |

**Server sees:**
```json
{
  "family_member_id": "7c9e6679-...",
  "encrypted_profile": "AQAAAACAAABZwg..."  // Contains: { name: "Emma", dob: "2020-03-15" }
}
```

**Why this matters**: Even if server database is breached, attacker sees UUIDs and ciphertext, not "Emma Smith, age 5, allergic to peanuts."

---

## 3. What Other Users Can See

### 3.1 Authorized Users (Granted Access)

**Adult B has been granted access to Emma's records:**

| Data | Visibility | How |
|------|-----------|-----|
| **Emma's medical records** | ✅ Full access | Decrypted with shared FMK |
| **Emma's name, DOB** | ✅ Full access | Encrypted in profile, decrypted with FMK |
| **Who else has access to Emma** | ❌ Cannot see | Access grants are user-specific |
| **Adult A's other family members** | ❌ Cannot see | No access to other FMKs |
| **Adult A's Master Key** | ❌ Cannot see | Never shared |

**Granularity**: Per-family-member. If Adult A shares Emma's records but not Liam's, Adult B sees:
- ✅ Emma: All records
- ❌ Liam: Nothing (not even existence)

### 3.2 Unauthorized Users

**Adult C has NOT been granted access:**

| Data | Visibility | Protection |
|------|-----------|-----------|
| **Emma's medical records** | ❌ Cannot decrypt | No FMK, only sees ciphertext |
| **Emma's existence** | ⚠️ Depends on design | If Adult C is family member, might see "Emma (no access)" in UI |
| **Server metadata** | ❌ No access | Supabase RLS prevents queries |

**Row-Level Security (RLS) example:**
```sql
-- Adult C tries to query Emma's records
SELECT * FROM medical_records WHERE family_member_id = '7c9e6679-...';

-- Supabase RLS policy blocks:
CREATE POLICY "Can only see granted records"
ON medical_records FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM family_member_access_grants
    WHERE family_member_id = medical_records.family_member_id
      AND granted_to_user_id = auth.uid()
      AND revoked_at IS NULL
  )
);

-- Result: Query returns 0 rows (Adult C has no grant)
```

**Even if Adult C breaches the server**, they only see encrypted blobs (no FMK to decrypt).

### 3.3 Verification Code Visibility

**Security codes (6-digit hex):**

| User | Can See Code | Why |
|------|-------------|-----|
| **Adult A** | ✅ Yes | Derived from shared secret (ECDH with Adult B) |
| **Adult B** | ✅ Yes | Same shared secret (ECDH with Adult A) |
| **Server** | ❌ No | Never transmitted, computed locally |
| **Adult C** | ❌ No | No shared secret with Adult A |

**Purpose**: Out-of-band verification (phone call, text) to detect MITM attacks.

---

## 4. What Attackers Can See

### 4.1 Network Eavesdropper (Passive)

**Attacker intercepts HTTPS traffic:**

| Attack | Visibility | Protection |
|--------|-----------|-----------|
| **Medical record content** | ❌ HTTPS + E2EE | Double encryption (TLS + AES-GCM) |
| **Wrapped FMKs** | ❌ HTTPS + Key Wrapping | Opaque blobs, useless without private key |
| **User emails** | ⚠️ Might see in TLS metadata | HTTPS encrypts, but SNI leaks domain |
| **Timing/volume** | ✅ Can see | When requests occur, data sizes |

**Conclusion**: Passive network eavesdropping reveals minimal information (standard for HTTPS apps).

### 4.2 Compromised Server (Active Attacker)

**Attacker gains root access to Supabase server:**

| Attack | Visibility | Protection |
|--------|-----------|-----------|
| **Medical record content** | ❌ Encrypted with FMKs | Zero-knowledge property holds |
| **User social graph** | ✅ Fully visible | Metadata not encrypted (design trade-off) |
| **Wrapped FMKs** | ⚠️ Can steal blobs, but useless | Cannot decrypt without user's private key |
| **User passwords** | ⚠️ Supabase hashes visible | Hashed with bcrypt (slow to crack) |
| **MITM on new invitations** | ✅ **Yes** (TOFU vulnerability) | Can inject fake public keys |

**Critical vulnerability**: Server MITM on first key exchange (TOFU model). See [Section 9: Attack Scenarios](#9-attack-scenarios-and-mitigations).

**Mitigation**: Verification codes (out-of-band), optional QR code sharing (Phase 4).

### 4.3 Malicious Insider (Server Admin)

**Supabase employee with database access:**

| Attack | Visibility | Limitation |
|--------|-----------|-----------|
| **Read medical records** | ❌ Cannot decrypt | No FMKs |
| **Build social graph** | ✅ Yes | Can see who shares with whom |
| **Correlate with external data** | ⚠️ Possible if emails leak | "alice@company.com shared with bob@company.com" |
| **Change user data** | ⚠️ Can modify ciphertext | Detected by authentication tags (AES-GCM) |

**Mitigation**:
- Zero-knowledge architecture prevents content access
- Audit logs for database modifications
- Consider: Encrypted metadata (Phase 4)

### 4.4 Compromised Client Device

**Attacker steals Adult A's iPhone:**

| Attack | Visibility | Protection |
|--------|-----------|-----------|
| **Medical records (device locked)** | ❌ Keychain protected | Requires device passcode/biometric |
| **Medical records (device unlocked)** | ✅ **Full access** | Keychain accessible when unlocked |
| **Master Key** | ✅ **Accessible** | Keychain protection only when locked |
| **Private Key** | ✅ **Accessible** (encrypted in Keychain) | Requires Master Key (also in Keychain) |

**Critical**: If device is unlocked, attacker has full access. This is fundamental to iOS security model.

**Mitigations**:
- Device encryption (hardware-backed on modern iPhones)
- Auto-lock timeout (user responsibility)
- Biometric authentication (Touch ID/Face ID)
- Future: Require biometric auth before accessing medical records (Phase 4)

### 4.5 Compromised User Account (Server-Side)

**Attacker steals Adult A's Supabase login credentials:**

| Attack | Visibility | Protection |
|--------|-----------|-----------|
| **Download encrypted records** | ✅ Can download | But cannot decrypt (no Master Key) |
| **Download wrapped FMKs** | ✅ Can download | But cannot unwrap (no private key) |
| **Issue new invitations** | ✅ **Yes** | Can invite arbitrary users |
| **Revoke access** | ✅ **Yes** | Can delete access grants |

**Critical**: Attacker can impersonate user for server operations, but cannot decrypt data (keys are device-only).

**Mitigations**:
- 2FA (Supabase supports, not in Phase 1)
- Email notifications for new invitations
- Audit trail (user can see "Unexpected invitation sent")

---

## 5. Threat Model Analysis

### 5.1 Threat Actors

| Actor | Capability | Motivation | Risk Level |
|-------|-----------|-----------|-----------|
| **Network Eavesdropper** | Passive HTTPS interception | Mass surveillance | Low (HTTPS protects) |
| **Server Admin (Honest-but-Curious)** | Database read access | Curiosity, analytics | Medium (sees metadata) |
| **Server Admin (Malicious)** | Database read/write | Data theft, MITM | High (TOFU vulnerability) |
| **State Actor with Warrant** | Server data seizure | Legal investigation | High (metadata + ciphertext) |
| **Device Thief** | Stolen unlocked phone | Opportunistic theft | High (full access) |
| **Malicious Family Member** | Authorized access to one patient | Abuse, stalking | Medium (limited to granted data) |
| **Hacker (Account Takeover)** | User credentials | Identity theft, data theft | Medium (server-only, can't decrypt) |

### 5.2 Assets to Protect (Priority Order)

1. **Medical record content** (highest sensitivity)
   - Diagnosis, medications, doctor notes
   - Protection: E2EE with AES-256-GCM, FMKs never on server

2. **User cryptographic keys**
   - Master Key, Private Key, FMKs
   - Protection: Device-only storage (Keychain), never transmitted

3. **User passwords**
   - Used for key derivation
   - Protection: Never transmitted, only Supabase hash stored

4. **Social graph metadata** (accepted trade-off)
   - Who shares with whom
   - Protection: None (required for async routing)

5. **Usage metadata**
   - Login times, record counts
   - Protection: Minimal (standard app analytics)

### 5.3 Attack Tree

```
Goal: Access Emma's Medical Records
├─ Compromise Server
│  ├─ Steal database dump
│  │  └─ Result: Encrypted records (useless without FMK) ❌
│  ├─ MITM on invitation (TOFU attack)
│  │  └─ Result: Intercept FMK during sharing ✅ (Mitigated by verification codes)
│  └─ Modify ciphertext
│     └─ Result: Detected by AES-GCM auth tag ❌
├─ Compromise Adult A's Device
│  ├─ Steal unlocked phone
│  │  └─ Result: Full access via Keychain ✅ (Accepted risk)
│  ├─ Steal locked phone
│  │  └─ Result: Keychain protected ❌ (Requires unlock)
│  └─ Malware on device
│     └─ Result: Keychain accessible if app running ✅ (iOS sandboxing limits)
├─ Compromise Adult A's Account (Server)
│  ├─ Steal Supabase credentials
│  │  └─ Result: Can download ciphertext, can't decrypt ❌
│  └─ Phishing attack
│     └─ Result: Same as above ❌
└─ Social Engineering
   ├─ Trick Adult A into sharing
   │  └─ Result: Legitimate access ✅ (User responsibility)
   └─ Trick Adult B into revealing verification code
      └─ Result: MITM detection bypassed ✅ (Out-of-band verification weakness)
```

**Key takeaways**:
- ✅ Server compromise doesn't reveal content (zero-knowledge holds)
- ⚠️ TOFU vulnerability requires active MITM (sophisticated attack)
- ⚠️ Device theft with unlocked phone is biggest risk (physical security)

### 5.4 Out-of-Scope Threats

**Not protected against** (accepted limitations):
1. **Malicious app binary**: If attacker modifies the app itself, all bets are off (mitigated by App Store code signing)
2. **iOS/hardware backdoors**: If Apple or hardware manufacturer is malicious (fundamental trust assumption)
3. **Compromised CryptoKit**: If Apple's crypto library is backdoored (industry-standard trust)
4. **Quantum computers**: AES-256 is quantum-resistant, but Curve25519 is not (acceptable for 2025 threat model)
5. **Rubber-hose cryptanalysis**: Physical coercion to reveal password (out of scope for software)

---

## 6. Privacy Benefits

### 6.1 Compared to Unencrypted Cloud Storage

**Traditional cloud (Google Drive, Dropbox, iCloud):**

| Feature | Unencrypted Cloud | Our E2EE App |
|---------|------------------|--------------|
| **Provider reads content** | ✅ Yes (terms of service) | ❌ No (zero-knowledge) |
| **Government warrant** | ✅ Reveals all data | ⚠️ Reveals metadata only |
| **Data breach impact** | ✅ Full PHI exposure | ⚠️ Ciphertext only |
| **Server admin access** | ✅ Full access | ❌ No content access |
| **AI training / scanning** | ✅ Possible (see Google Photos) | ❌ Impossible (encrypted) |

**Example**: iCloud Photos scans for CSAM (controversial). Our app cannot scan encrypted medical records.

### 6.2 Compared to HIPAA-Compliant Systems

**Traditional HIPAA systems (hospital EMRs):**

| Feature | HIPAA EMR | Our E2EE App |
|---------|-----------|--------------|
| **Encryption at rest** | ✅ Yes (server-side) | ✅ Yes (client-side E2EE) |
| **Encryption in transit** | ✅ Yes (TLS) | ✅ Yes (TLS + E2EE) |
| **Provider access** | ✅ Admins can decrypt | ❌ Provider cannot decrypt |
| **Audit logs** | ✅ Required | ⚠️ Metadata only |
| **User control** | ⚠️ Limited (provider controls data) | ✅ Full (user owns keys) |

**Key difference**: HIPAA protects **who** can access data (access control), we protect **what** can be accessed (cryptographic control). HIPAA admins can decrypt; ours cannot.

### 6.3 Compared to Password Managers (1Password, Bitwarden)

**Our app uses similar architecture:**

| Feature | 1Password | Our App |
|---------|-----------|---------|
| **Zero-knowledge** | ✅ Yes | ✅ Yes |
| **Key derivation** | ✅ PBKDF2 + Secret Key | ✅ PBKDF2 (or Argon2id) |
| **Sharing model** | ✅ Public-key sharing | ✅ ECDH + Key Wrapping |
| **Metadata exposure** | ⚠️ Knows who shares with whom | ⚠️ Same |
| **Audit trail** | ✅ Yes | ⚠️ Phase 4 |

**Privacy level**: Comparable to 1Password (industry gold standard for consumer zero-knowledge).

### 6.4 Unique Privacy Benefits

**What makes our approach strong:**

1. ✅ **Per-Family-Member Granularity**: Share Emma's records, not "all my data"
2. ✅ **Offline-First**: No server round-trips for decryption (privacy + performance)
3. ✅ **Device-Only Master Key**: Cannot be extracted even with server breach
4. ✅ **CryptoKit Hardware Backing**: Leverages Secure Enclave on modern iPhones
5. ✅ **Minimal Data Collection**: No analytics by default (can be added opt-in)
6. ✅ **Open Algorithm Disclosure**: Research docs transparently explain crypto (this document!)

---

## 7. Metadata Leakage Deep Dive

### 7.1 What is Metadata?

**Metadata = "Data about data"**

| Content (E2EE Protected) | Metadata (Not E2EE Protected) |
|--------------------------|-------------------------------|
| "Emma has peanut allergy" | "User A has 15 records for family member X" |
| "COVID vaccine 2023-05-15" | "User A shared family member X with User B" |
| "Dr. Smith prescribed amoxicillin" | "User A logged in at 2pm from San Francisco" |

**Why it matters**: Even without reading content, metadata can reveal sensitive patterns.

### 7.2 Types of Metadata Leaked

#### 7.2.1 Social Graph Metadata

**Server knows:**
```
User A (550e8400-...) shared:
  - Family Member X (7c9e6679-...) with User B (9b2e8400-...)
  - Family Member Y (3f5a2b1c-...) with User C (1a3f9d2e-...)

User B shared:
  - Family Member Z (8d4c5e6f-...) with User A
```

**Implications:**
- ⚠️ Can infer relationships: "A and B share each other's family members → likely spouses"
- ⚠️ Can count connections: "User A has 5 sharing relationships → large family"
- ⚠️ Can detect clusters: "Users A, B, C all share with each other → family unit"

**Real-world example**: If Alice shares Emma (child) and Michael (child) with Bob, and Bob shares Linda (child) with Alice, server infers:
- Alice and Bob are likely co-parents
- Emma, Michael, Linda are likely siblings
- This is a 2-parent household with 3 children

#### 7.2.2 Volume Metadata

**Server knows:**
```
Family Member X (7c9e6679-...) has:
  - 15 vaccine records
  - 3 allergy records
  - 42 medical visit records
  - Total encrypted data: 125 KB
```

**Implications:**
- ⚠️ High record count suggests chronic condition (frequent doctor visits)
- ⚠️ Large data size suggests scanned documents (specialist reports?)
- ⚠️ Sudden spike in records suggests medical event

**Real-world example**: If family member has 2 records in 2024, then suddenly 50 records in January 2025:
- Server knows: "Medical event occurred in January"
- Server doesn't know: "Cancer diagnosis" (content encrypted)

#### 7.2.3 Temporal Metadata

**Server knows:**
```
User A:
  - Created account: 2024-01-15
  - Last login: 2025-01-20 14:22:00
  - Login frequency: Daily (2pm PT)
  - Record creation pattern: Spike every 3 months
```

**Implications:**
- ⚠️ Regular login pattern suggests monitoring chronic condition
- ⚠️ Quarterly spikes suggest routine checkups
- ⚠️ Sudden inactivity after regular use suggests... something (hospitalization? Lost interest?)

#### 7.2.4 Category Metadata (If Plaintext)

**If `record_type` is plaintext:**
```
Family Member X has:
  - 15 records with type: "vaccine"
  - 3 records with type: "allergy"
  - 1 record with type: "surgery"
```

**Implications:**
- ⚠️ Knows health categories (not specific diagnoses)
- ⚠️ "Surgery" record reveals major medical event
- ⚠️ Can correlate: "3 allergy records created same day → severe allergic reaction?"

**Design choice**: We can encrypt `record_type` if filtering happens client-side. Trade-off: Slower UX (can't server-filter "show all vaccines").

### 7.3 Statistical Inference Attacks

**Sophisticated attacker with metadata access:**

#### Attack 1: Size-Based Inference
```
Observation: Record for family member X is 1.2 MB (much larger than others)
Inference: Likely scanned document (e.g., radiology report, genetic test)
Correlation: If created after 15 vaccine records, might be vaccine injury report
```

**Mitigation**: Padding (make all records same size). Trade-off: Wasted bandwidth.

#### Attack 2: Timing Correlation
```
Observation: User A and User B both create records for same family member within 1 hour
Inference: Doctor visit (both parents updating records from same appointment)
Correlation: If happens every 3 months, routine pediatric checkup
```

**Mitigation**: Delayed sync (random delay before uploading). Trade-off: Less real-time.

#### Attack 3: Social Graph Analysis
```
Observation: Users A, B, C, D, E all share with each other (fully connected graph)
Inference: Extended family (grandparents, aunts/uncles)
Correlation: If one user (E) suddenly stops sharing, family conflict? Legal issue?
```

**Mitigation**: None (fundamental to sharing model). Encrypted metadata helps but doesn't eliminate.

### 7.4 Comparison: Signal's Metadata

**Signal Protocol also leaks metadata:**

| Metadata Type | Signal | Our App |
|---------------|--------|---------|
| **Who talks to whom** | ✅ Server knows | ✅ Server knows |
| **When messages sent** | ✅ Server knows | ✅ Server knows (record creation) |
| **Message sizes** | ✅ Server knows | ✅ Server knows (record sizes) |
| **Sender identity** | ⚠️ Sealed Sender hides | ❌ Not hidden (less critical for medical) |
| **Contact lists** | ❌ Not uploaded | ❌ Not uploaded |
| **Group membership** | ⚠️ Encrypted metadata | ⚠️ Could encrypt family relationships |

**Key insight**: Even Signal (gold standard for E2EE) leaks routing metadata. Difference: They minimize retention and use Sealed Sender to hide *some* metadata.

### 7.5 Is This Acceptable?

**Yes, for these reasons:**

1. **Threat Model**: Medical records are static data (not high-value real-time intelligence)
   - NSA cares about "who is planning terrorism" (messaging metadata valuable)
   - Less interested in "who shares their child's vaccine records" (lower intelligence value)

2. **Risk vs. UX**: Family medical app must be convenient or won't be used
   - If too hard to share, users fall back to unencrypted email/photos
   - Better to have E2EE content with metadata leakage than no encryption at all

3. **Authorized Access**: Social graph reveals family relationships (already known to family members)
   - Not like whistleblower/journalist protecting source identity
   - Family members know who else in family (metadata reveals little new)

4. **Future Hardening**: Can add encrypted metadata (Phase 4) without breaking existing design
   - Start simple, add privacy layers later
   - Migration path: Re-encrypt metadata with user keys

**Trade-off accepted**: Content zero-knowledge now, metadata zero-knowledge later (if needed).

---

## 8. Comparison to Alternatives

### 8.1 Encrypted Metadata Alternative

**What if we encrypted ALL metadata?**

#### Implementation:
```sql
CREATE TABLE family_member_access_grants (
    grant_id UUID PRIMARY KEY,
    recipient_user_id UUID,  -- Only plaintext (for routing)
    encrypted_metadata BYTEA,  -- Contains: { family_member_id, wrapped_fmk, granter_id }
    created_at TIMESTAMPTZ
);
```

**Client-side flow:**
```
Adult B downloads all access grants for themselves:
├─ Server returns: 50 encrypted_metadata blobs
├─ Client decrypts each blob locally
├─ Filters: "Show me Emma's access grant"
└─ Result: Found after decrypting 23rd blob
```

#### Comparison:

| Feature | Plaintext Metadata (Current) | Encrypted Metadata |
|---------|----------------------------|-------------------|
| **Server knows social graph** | ✅ Yes | ❌ No |
| **Server knows family member IDs** | ✅ Yes | ❌ No (encrypted) |
| **Volume leakage** | ✅ "User has 50 grants" | ✅ Same (count visible) |
| **Client-side performance** | ✅ Fast (SQL query) | ⚠️ Slower (decrypt all, filter) |
| **Server-side search** | ✅ Possible | ❌ Impossible |
| **Complexity** | ✅ Simple | ⚠️ More complex |
| **Async support** | ✅ Full | ✅ Full |

**Verdict**: Encrypted metadata is **possible** and provides better privacy. Trade-off: Performance and complexity.

**Recommendation**: Phase 4 enhancement (opt-in for privacy-focused users).

### 8.2 QR Code Sharing Alternative

**What if we used QR codes instead of email invitations?**

#### Implementation:
```
Adult A generates QR code:
├─ Contains: { public_key, wrapped_fmk, family_member_id }
├─ Adult B scans QR code in person
└─ No server involved in key exchange
```

#### Comparison:

| Feature | Email Invitation (Current) | QR Code Sharing |
|---------|---------------------------|-----------------|
| **Server knows social graph** | ✅ Yes | ❌ No (no invitation record) |
| **Requires in-person meeting** | ❌ No (async, remote) | ✅ Yes |
| **Works for remote families** | ✅ Yes | ❌ No |
| **MITM vulnerability** | ⚠️ Yes (TOFU) | ❌ No (direct transfer) |
| **UX friction** | ✅ Low (one click) | ⚠️ Medium (scan QR) |
| **Async support** | ✅ Full | ⚠️ Partial (key exchange sync, data async) |

**Verdict**: QR code is **most private** but **least convenient**. Not a replacement, but a complementary option.

**Recommendation**: Phase 4 addition (offer both email and QR code).

### 8.3 Fully Peer-to-Peer Alternative

**What if we eliminated the server entirely?**

#### Implementation:
```
Adult A and Adult B connect directly:
├─ Via local network (Bonjour/MultipeerConnectivity)
├─ Or via iCloud Drive (file-based sync)
└─ No central server
```

#### Comparison:

| Feature | Server Mailbox (Current) | Fully P2P |
|---------|-------------------------|-----------|
| **Metadata privacy** | ⚠️ Server sees graph | ✅ Perfect (no server) |
| **Async support** | ✅ Full | ⚠️ Limited (iCloud sync possible) |
| **Works remotely** | ✅ Yes | ⚠️ Requires iCloud or manual file transfer |
| **Reliability** | ✅ High (server always available) | ⚠️ Lower (peer availability) |
| **Complexity** | ✅ Medium | ⚠️ High (P2P coordination) |
| **Conflict resolution** | ✅ Server-side timestamps | ⚠️ Complex (CRDTs?) |

**Verdict**: P2P offers maximum privacy but poor reliability/UX. Not practical for family app.

**Recommendation**: Not pursuing (too complex for hobby app).

---

## 9. Attack Scenarios and Mitigations

### 9.1 Scenario: Malicious Server MITM (TOFU Attack)

**Attack**:
```
Day 1: Alice sends invitation to Bob
├─ Email contains: Alice's public key
├─ Malicious server intercepts
├─ Server replaces with attacker's public key
└─ Bob receives email with attacker's key (thinks it's Alice's)

Day 3: Bob accepts invitation
├─ Bob generates keypair
├─ Server performs ECDH with attacker's private key
├─ Server unwraps FMK_Emma
└─ Server can now decrypt Emma's records ⚠️
```

**Probability**: Low (requires malicious/compromised server + targeted attack)

**Detection**:
```
Alice and Bob compare verification codes:
├─ Alice computes: SHA256(ECDH(Alice_Private, Bob_Public)).prefix(3) = "A3-5F-2B"
├─ Bob computes: SHA256(ECDH(Bob_Private, Alice_Public)).prefix(3) = "F1-8C-99"
└─ Codes don't match → MITM detected ✅
```

**Mitigations**:
1. ✅ **Verification codes** (out-of-band comparison via phone call)
2. ✅ **UI warning**: "If codes don't match, DO NOT share sensitive data"
3. ⚠️ **Future**: Mandatory verification for high-sensitivity accounts (opt-in)
4. ⚠️ **Future**: QR code option (bypasses server for key exchange)

**Residual risk**: Users might skip verification (UX friction). Accepted trade-off.

### 9.2 Scenario: Stolen Unlocked Device

**Attack**:
```
Thief steals Alice's unlocked iPhone:
├─ Opens Family Medical App (already unlocked)
├─ iOS Keychain accessible (device unlocked)
├─ App retrieves Master Key from Keychain
├─ App decrypts all medical records
└─ Full access ⚠️
```

**Probability**: Medium (opportunistic theft, device left unlocked)

**Mitigations**:
1. ✅ **Device auto-lock** (user responsibility, iOS default)
2. ✅ **Biometric protection** (Touch ID/Face ID)
3. ⚠️ **Future**: App-level biometric auth (require Face ID before viewing records)
4. ⚠️ **Future**: Remote wipe via Find My iPhone

**Residual risk**: If device is unlocked, Keychain is accessible. Fundamental iOS limitation.

**Accepted trade-off**: Same as Apple Wallet, banking apps (rely on device lock).

### 9.3 Scenario: Compromised Server Database Dump

**Attack**:
```
Hacker breaches Supabase, steals database:
├─ Downloads all tables:
│   ├─ user_profiles (emails, public keys)
│   ├─ medical_records (encrypted blobs)
│   ├─ family_member_access_grants (wrapped FMKs)
│   └─ invitations (social graph)
├─ Attempts to decrypt:
│   ├─ Medical records → Requires FMKs ❌
│   ├─ Wrapped FMKs → Requires private keys ❌
│   └─ Private keys → Not in database ❌
└─ Result: Metadata only (social graph visible)
```

**Probability**: Medium (server breaches happen)

**Impact**:
- ✅ **Content protected**: Zero-knowledge holds
- ⚠️ **Metadata exposed**: Social graph, record counts, timestamps
- ⚠️ **Email addresses exposed**: PII leakage

**Mitigations**:
1. ✅ **Zero-knowledge architecture**: Content unreadable
2. ✅ **Encrypted columns**: Wrapped FMKs are opaque blobs
3. ⚠️ **Future**: Encrypted metadata (social graph protection)
4. ⚠️ **Future**: Anonymized emails (e.g., email hash for lookups)

**Residual risk**: Metadata leakage. Accepted for Phase 1.

### 9.4 Scenario: Malicious Family Member

**Attack**:
```
Alice shares Emma's records with Bob (authorized)
Bob becomes malicious:
├─ Can decrypt all Emma's records ✅ (legitimate access)
├─ Cannot decrypt Liam's records ❌ (not granted)
├─ Cannot share with others ⚠️ (no FMK to re-wrap)
└─ Can export data locally (screenshot, export PDF)
```

**Probability**: Low (family trust model)

**Impact**:
- ⚠️ **Authorized data accessible**: Bob can read Emma's records (intended)
- ✅ **Unauthorized data protected**: Bob cannot access Liam's records
- ⚠️ **Re-sharing prevented**: Bob cannot grant access to others (no owner privileges)

**Mitigations**:
1. ✅ **Granular access control**: Per-family-member, not all-or-nothing
2. ✅ **Revocation**: Alice can revoke Bob's access (see ADR-0005)
3. ⚠️ **Future**: Audit trail (log when Bob accesses Emma's records)
4. ⚠️ **Future**: Read-only mode (prevent local export)

**Residual risk**: Authorized users can misuse data. Fundamental to sharing model.

**Accepted trade-off**: Same as Google Docs (shared doc can be copied/saved).

### 9.5 Scenario: Account Takeover (Credentials Stolen)

**Attack**:
```
Hacker steals Alice's Supabase credentials:
├─ Logs into Alice's account (server-side)
├─ Downloads encrypted medical records ✅
├─ Downloads wrapped FMKs ✅
├─ Attempts to decrypt:
│   ├─ Needs FMK → Needs to unwrap → Needs private key ❌
│   └─ Private key in Keychain (device-only) ❌
├─ Can issue new invitations ⚠️ (impersonation)
└─ Can revoke existing access ⚠️ (denial of service)
```

**Probability**: Medium (phishing, credential reuse)

**Impact**:
- ✅ **Content protected**: Cannot decrypt (no device access)
- ⚠️ **Impersonation possible**: Can invite malicious users
- ⚠️ **DoS possible**: Can revoke legitimate access

**Mitigations**:
1. ✅ **2FA** (Supabase supports, Phase 4)
2. ✅ **Email notifications**: "New invitation sent" (user can detect unauthorized)
3. ⚠️ **Future**: Require device confirmation for critical actions (invite, revoke)
4. ⚠️ **Future**: Audit trail (Alice can see "Unexpected invitation from SF IP")

**Residual risk**: Server-side impersonation possible. Accepted for Phase 1 (2FA mitigates).

---

## 10. Privacy-Enhancing Roadmap

### Phase 1-3: Current Design (Content Zero-Knowledge)
- ✅ Medical records encrypted (AES-256-GCM)
- ✅ FMKs wrapped (ECDH + AES.KeyWrap)
- ✅ Device-only master keys
- ⚠️ Metadata exposed (social graph, volume, timing)

### Phase 4a: Encrypted Metadata (Optional Hardening)
- Encrypt social graph (family_member_id, granter_id)
- Client-side filtering (download all, decrypt locally)
- Trade-off: Performance vs. metadata privacy
- Opt-in for privacy-focused users

### Phase 4b: QR Code Sharing (Maximum Privacy)
- In-person key exchange (no server MITM)
- Complementary to email invitations
- Best metadata privacy (server uninvolved)
- Trade-off: Requires in-person meeting

### Phase 4c: Audit Trail (Transparency)
- Encrypted logs of access events
- "Who accessed Emma's records when"
- Detect unauthorized access
- Trade-off: Additional metadata collected

### Phase 4d: 2FA and Device Confirmation
- Two-factor authentication (Supabase)
- Device-based confirmation for critical actions
- Prevents account takeover impact
- Trade-off: UX friction for security

### Phase 5: Advanced Mitigations (Speculative)
- Padding (uniform record sizes)
- Delayed sync (random timing)
- Anonymized email lookups (hash-based)
- Mix networks (metadata obfuscation)
- Trade-off: Significant complexity

---

## Conclusion

### Honest Assessment

**What we protect:**
- ✅ **Medical record content**: Strong zero-knowledge (AES-256-GCM E2EE)
- ✅ **Cryptographic keys**: Device-only, never on server
- ✅ **User passwords**: Never transmitted (local derivation only)

**What we don't protect:**
- ⚠️ **Social graph**: Server knows who shares with whom
- ⚠️ **Volume metadata**: Server knows record counts, sizes
- ⚠️ **Usage patterns**: Server knows login times, sync frequency
- ⚠️ **TOFU vulnerability**: Server can MITM first key exchange (mitigated by verification codes)

**Our privacy level**: Comparable to **1Password, Bitwarden, Signal** (content zero-knowledge, metadata exposure for routing).

**Not comparable to**: Tor, Zcash, fully anonymous systems (different use case, extreme complexity).

### Transparency Commitment

This document represents **honest disclosure** of privacy properties. We acknowledge:
1. ✅ Not "fully zero-knowledge" (metadata exposed)
2. ✅ Trade-offs made for UX and async support
3. ✅ Future hardening possible (encrypted metadata, QR codes)
4. ✅ Risk-appropriate for family medical app (not whistleblower/dissident protection)

### For Security Auditors

**Key claims to verify:**
1. Server cannot decrypt medical record content (verify: no FMKs on server)
2. Master Keys never transmitted (verify: Keychain-only storage)
3. ECDH shared secrets ephemeral (verify: computed in-memory, not stored)
4. AES-GCM authentication tags prevent tampering (verify: tag validation)
5. TOFU vulnerability mitigated by verification codes (verify: out-of-band check)

**Audit trail**: See `docs/adr/` for all cryptographic decisions.

---

**Document Version**: 1.0
**Last Updated**: 2025-12-20
**Next Review**: After Phase 4 (encrypted metadata implementation)

## References

- ADR-0002: Key Hierarchy and Derivation
- ADR-0003: Multi-User Sharing Model
- `docs/research/e2ee-sharing-patterns-research.md`
- [Signal Privacy Policy](https://signal.org/legal/#privacy-policy)
- [1Password Security Design](https://agilebits.github.io/security-design/)
- [NIST SP 800-175B: Key Management](https://csrc.nist.gov/publications/detail/sp/800-175b/final)
