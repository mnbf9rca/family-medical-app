# Wiki-Style Record Versioning and Conflict Resolution

**Status**: Accepted
**Date**: 2025-12-22
**Supersedes**: Last-write-wins conflict resolution
**Related**: Issue #48 (Conflict Resolution), ADR-0004 (Sync Encryption)

---

## Overview

Each medical record (vaccination, medication, provider, etc.) functions like a **Wikipedia article** with immutable revision history:

- Every edit creates a new **version** (never modifies existing versions)
- All versions are **immutable** and retained permanently
- Users can **view history** and **restore** previous versions
- **No conflict detection needed** - concurrent edits both succeed and appear in history

This design eliminates data loss from concurrent edits while providing familiar Wikipedia-like version history UX.

---

## Architecture

### Conceptual Model

```
Medical Record = Wikipedia Article
├─ record_id (the "wiki page" ID - permanent)
├─ Versions (revisions)
│  ├─ Version 1: Initial creation
│  ├─ Version 2: User corrected date
│  ├─ Version 3: Added batch number
│  └─ Version 4 (current): Attached vaccine card photo
└─ Cross-references
   └─ Links to other records (provider, medications, etc.)
```

### Database Schema

```sql
CREATE TABLE records (
    -- Record identity
    record_id UUID NOT NULL,          -- Permanent ID (like Wikipedia page ID)
    version INTEGER NOT NULL,          -- Revision number (auto-increment per record)
    family_member_id UUID NOT NULL,    -- Which patient this belongs to

    -- Document type and content
    record_type TEXT NOT NULL,         -- 'vaccination', 'medical_provider', 'medication', etc.
    encrypted_document BYTEA NOT NULL, -- Arbitrary JSON structure (encrypted)
    nonce BYTEA NOT NULL,
    tag BYTEA NOT NULL,

    -- Version metadata
    created_at TIMESTAMPTZ NOT NULL,   -- When this version was created
    created_by_device_id UUID NOT NULL,
    created_by_user_id UUID NOT NULL,  -- For family sharing
    is_current BOOLEAN NOT NULL DEFAULT true,

    -- Optional change summary (like Wikipedia edit summary)
    encrypted_change_summary BYTEA,    -- "Corrected vaccination date"

    PRIMARY KEY (record_id, version)
);

-- Performance indexes
CREATE INDEX idx_current_records
    ON records(family_member_id, record_type, created_at DESC)
    WHERE is_current = true;

CREATE INDEX idx_record_history
    ON records(record_id, version DESC);

-- Cross-references between records
CREATE TABLE record_references (
    source_record_id UUID NOT NULL,
    source_version INTEGER NOT NULL,
    target_record_id UUID NOT NULL,
    reference_type TEXT NOT NULL,      -- 'administered_by', 'prescribed_by', etc.

    FOREIGN KEY (source_record_id, source_version)
        REFERENCES records(record_id, version)
);
```

---

## Document Structure (Flexible JSON)

Each encrypted document contains arbitrary JSON tailored to its type:

### Vaccination Record Example

```json
// Version 1: Initial creation
{
  "record_type": "vaccination",
  "vaccine_name": "Pfizer COVID-19",
  "date_administered": "2024-03-15",
  "dose_number": 1,
  "batch_number": "EK1234",
  "administered_by": "record-uuid-456",  // Reference to MedicalProvider
  "site": "Left arm",
  "notes": "No adverse reactions",
  "attachments": []
}

// Version 2: User corrected the date
{
  "record_type": "vaccination",
  "vaccine_name": "Pfizer COVID-19",
  "date_administered": "2024-03-16",  // ← Changed
  "dose_number": 1,
  "batch_number": "EK1234",
  "administered_by": "record-uuid-456",
  "site": "Left arm",
  "notes": "No adverse reactions",
  "attachments": []
}

// Version 3: Added vaccine card photo
{
  "record_type": "vaccination",
  "vaccine_name": "Pfizer COVID-19",
  "date_administered": "2024-03-16",
  "dose_number": 1,
  "batch_number": "EK1234",
  "administered_by": "record-uuid-456",
  "site": "Left arm",
  "notes": "No adverse reactions",
  "attachments": ["attachment-uuid-789"]  // ← Added
}
```

### Medical Provider Record Example

```json
{
  "record_type": "medical_provider",
  "name": "Dr. Sarah Smith",
  "clinic": "City Health Center",
  "phone": "+1-555-0123",
  "email": "sarah.smith@cityhealthcenter.org",
  "specialization": "Family Medicine",
  "address": {
    "street": "123 Main St",
    "city": "Portland",
    "state": "OR",
    "zip": "97201"
  }
}
```

### Medication Record Example

```json
{
  "record_type": "medication",
  "name": "Amoxicillin",
  "dosage": "500mg",
  "frequency": "3x daily",
  "prescribed_by": "record-uuid-456",  // Reference to MedicalProvider
  "prescribed_date": "2024-11-15",
  "start_date": "2024-11-16",
  "end_date": "2024-11-23",
  "reason": "Bacterial infection",
  "notes": "Take with food"
}
```

---

## Conflict Resolution Algorithm

### Core Principle: All Writes Succeed

Unlike traditional conflict resolution (where one write "wins"), **every edit creates a new version**. There are no conflicts, only history.

### Algorithm Steps

#### 1. On Write (Create or Update)

```swift
func saveRecord(familyMemberId: UUID, recordId: UUID?, document: Document,
                changeSummary: String?) throws -> UUID {

    let actualRecordId = recordId ?? UUID()

    // Fetch current max version (or 0 if new record)
    let currentVersion = try database.query(
        "SELECT COALESCE(MAX(version), 0) FROM records WHERE record_id = $1",
        [actualRecordId]
    ).first?.version ?? 0

    let newVersion = currentVersion + 1

    // Mark previous version as non-current (if exists)
    if newVersion > 1 {
        try database.execute(
            "UPDATE records SET is_current = false WHERE record_id = $1 AND is_current = true",
            [actualRecordId]
        )
    }

    // Encrypt document
    let fmk = try loadFamilyMemberKey(familyMemberId)
    let (encryptedDoc, nonce, tag) = try encryptDocument(document, using: fmk)

    // Encrypt change summary (optional)
    let encryptedSummary = changeSummary.map {
        try encryptText($0, using: fmk)
    }

    // Insert new version
    try database.execute("""
        INSERT INTO records (
            record_id, version, family_member_id, record_type,
            encrypted_document, nonce, tag,
            created_at, created_by_device_id, created_by_user_id,
            is_current, encrypted_change_summary
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), $8, $9, true, $10)
        """,
        [actualRecordId, newVersion, familyMemberId, document.type,
         encryptedDoc, nonce, tag, deviceId, userId, encryptedSummary]
    )

    // Extract and store cross-references
    try updateCrossReferences(recordId: actualRecordId, version: newVersion, document: document)

    return actualRecordId
}
```

#### 2. On Read (Current State Only)

```swift
// Fetch all current vaccinations for Emma
let vaccinations = try database.query("""
    SELECT record_id, encrypted_document, nonce, tag, created_at
    FROM records
    WHERE family_member_id = $1
      AND record_type = 'vaccination'
      AND is_current = true
    ORDER BY created_at DESC
    """,
    [emmaId]
)
```

#### 3. On Read (Full History for Single Record)

```swift
// Fetch all versions of a specific vaccination
let history = try database.query("""
    SELECT version, encrypted_document, nonce, tag,
           created_at, created_by_user_id, encrypted_change_summary
    FROM records
    WHERE record_id = $1
    ORDER BY version DESC
    """,
    [vaccinationRecordId]
)
```

#### 4. On Restore Previous Version

```swift
func restoreVersion(recordId: UUID, targetVersion: Int) throws {
    // Fetch the old version's content
    let oldVersion = try database.query(
        "SELECT encrypted_document, nonce, tag FROM records WHERE record_id = $1 AND version = $2",
        [recordId, targetVersion]
    ).first!

    // Decrypt it
    let fmk = try loadFamilyMemberKey(...)
    let oldDocument = try decryptDocument(oldVersion.encrypted_document,
                                          nonce: oldVersion.nonce,
                                          tag: oldVersion.tag,
                                          using: fmk)

    // Create a new version with the old content
    try saveRecord(
        familyMemberId: ...,
        recordId: recordId,
        document: oldDocument,
        changeSummary: "Restored from version \(targetVersion)"
    )
}
```

---

## Conflict Scenarios (All Resolved)

### Scenario 1: Concurrent Edits (Different Devices, Offline)

```
Timeline:
10:00 AM - iPhone (offline): Edit Emma's vaccination, creates version 2
10:05 AM - iPad (offline):  Edit same vaccination, creates version 3
11:00 AM - iPhone syncs:    Server stores version 2
11:02 AM - iPad syncs:      Server stores version 3 (is_current = true)

Result:
- Version 2: Created by iPhone, is_current = false
- Version 3: Created by iPad, is_current = true
- Both edits are preserved
- User can restore version 2 if needed

No data loss ✅
```

### Scenario 2: Exact Timestamp Tie

```
Timeline:
10:00:00.000 - Device A uploads version 2
10:00:00.000 - Device B uploads version 3 (same millisecond)

Result:
- Both succeed (database uses auto-increment version numbers)
- Whichever arrives first gets version 2, second gets version 3
- Order doesn't matter - user sees both in history

No non-determinism ✅
```

### Scenario 3: Delete vs Modify

```
Timeline:
10:00 AM - Device A deletes record (creates "tombstone" version with deleted=true)
10:05 AM - Device B modifies record (creates new version with updated content)

Result:
- Both versions exist
- Latest version (modify) is current
- User sees record is not deleted
- History shows deletion attempt at 10:00 AM

User can understand what happened ✅
```

### Scenario 4: S3 Manifest Merge

```
Before:
- Local manifest: records [A, B, C], versions: {A: 2, B: 1, C: 1}
- Remote manifest: records [A, B, D], versions: {A: 3, B: 1, D: 1}

After merge:
- Union: records [A, B, C, D]
- Max versions: {A: 3 (remote), B: 1 (either), C: 1 (local), D: 1 (remote)}

Result:
- All records preserved
- Version 3 of A becomes current
- C and D both included

No silent data loss ✅
```

---

## Cross-References

### Storing References

When a record references another (e.g., vaccination → provider):

```swift
func updateCrossReferences(recordId: UUID, version: Int, document: Document) throws {
    // Parse document for references
    let references = extractReferences(from: document)

    // Store each reference
    for ref in references {
        try database.execute("""
            INSERT INTO record_references
            (source_record_id, source_version, target_record_id, reference_type)
            VALUES ($1, $2, $3, $4)
            """,
            [recordId, version, ref.targetId, ref.type]
        )
    }
}

func extractReferences(from document: Document) -> [Reference] {
    var refs: [Reference] = []

    // Check known reference fields by document type
    switch document.type {
    case "vaccination":
        if let providerId = document["administered_by"] as? UUID {
            refs.append(Reference(targetId: providerId, type: "administered_by"))
        }
    case "medication":
        if let providerId = document["prescribed_by"] as? UUID {
            refs.append(Reference(targetId: providerId, type: "prescribed_by"))
        }
    // ... other types
    }

    return refs
}
```

### Querying References

```swift
// Find all vaccinations administered by Dr. Smith
let vaccinations = try database.query("""
    SELECT r.record_id, r.encrypted_document, r.nonce, r.tag
    FROM records r
    JOIN record_references ref ON r.record_id = ref.source_record_id
                                AND r.version = ref.source_version
    WHERE ref.target_record_id = $1
      AND ref.reference_type = 'administered_by'
      AND r.record_type = 'vaccination'
      AND r.is_current = true
    """,
    [drSmithRecordId]
)
```

---

## User Experience

### List View (Current Records Only)

```
Emma's Vaccinations
━━━━━━━━━━━━━━━━━━━━
• Pfizer COVID-19 Dose 1
  March 16, 2024 • Dr. Sarah Smith
  Last edited: Dec 20, 2025 10:15 AM
  [View] [Edit] [History]

• MMR Booster
  January 10, 2024 • City Pediatrics
  Last edited: Jan 10, 2024 9:30 AM
  [View] [Edit] [History]
```

### Detail View (Single Record, Current Version)

```
Pfizer COVID-19 Vaccination
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Date: March 16, 2024
Dose: 1 of 2
Batch: EK1234
Administered by: Dr. Sarah Smith (City Health Center)
Site: Left arm
Notes: No adverse reactions

Attachments:
• vaccine_card.jpg

Last edited: Dec 20, 2025 10:15 AM by You (iPhone)

[Edit] [View History] [Delete]
```

### History View (Wikipedia-Style)

```
Pfizer COVID-19 Vaccination - Revision History
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Version 3 (Current) ⭐
  Dec 20, 2025 10:15 AM • You (iPhone)
  Summary: "Attached vaccine card photo"
  Changes:
    • Added attachment: vaccine_card.jpg
  [View This Version]

Version 2
  Dec 20, 2025 9:45 AM • You (iPhone)
  Summary: "Corrected vaccination date"
  Changes:
    • date_administered: "2024-03-15" → "2024-03-16"
  [View This Version] [Restore This Version]

Version 1
  Dec 20, 2025 9:00 AM • You (iPhone)
  Summary: "Initial creation"
  Initial creation
  [View This Version] [Restore This Version]
```

### Restore Confirmation

```
Restore Version 2?
━━━━━━━━━━━━━━━━━

You're about to restore this version:
  Date: March 16, 2024 (no changes)
  Attachments: None (vaccine_card.jpg will be removed)

This will create a new version (version 4) with the
content from version 2. Version 3 will remain in history.

[Cancel] [Restore]
```

---

## Storage Impact

### Calculation

**Assumptions:**

- 100 medical records per patient (vaccinations, medications, providers, etc.)
- 10% edited per year (10 records)
- Average record size: 500 bytes encrypted

**Storage over time:**

| Year | New Versions Created | Total Versions | Total Storage |
|------|---------------------|----------------|---------------|
| 0 | 100 (initial) | 100 | 50 KB |
| 1 | 10 (edits) | 110 | 55 KB |
| 2 | 10 (edits) | 120 | 60 KB |
| 5 | 10/year | 150 | 75 KB |
| 10 | 10/year | 200 | 100 KB |

**Result**: 100 KB per patient after 10 years (100% increase)

**Cost analysis:**

- **Supabase**: $0.021/GB/month = $0.000002/month for 100 KB = negligible
- **S3**: $0.023/GB/month = $0.000002/month for 100 KB = negligible
- **iPhone Storage**: 100 KB is 0.0001% of 128 GB = invisible to user

**Conclusion**: Storage cost is **completely negligible** for medical records use case.

---

## Implementation Phases

### Phase 2 (Multi-Device Sync)

**Minimum Viable:**

- ✅ Schema with version column and is_current flag
- ✅ Create/update creates new version
- ✅ Read fetches is_current = true only
- ❌ No history UI yet (stored but not visible)

**Why defer history UI**: Phase 2 focus is sync reliability. Version storage ensures no data loss from concurrent edits.

### Phase 3 (Family Sharing)

**Add history viewing:**

- ✅ "View History" button in detail view
- ✅ List all versions with metadata
- ✅ Diff view showing changes between versions
- ❌ Restore not yet implemented

### Phase 4 (Polish)

**Full Wikipedia experience:**

- ✅ Restore previous versions
- ✅ Visual diff with highlighted changes
- ✅ Conflict notifications ("Your edit and Bob's edit both succeeded")
- ✅ Export full history to PDF

---

## Security Considerations

### Encryption Scope

Each version is **independently encrypted** with the FMK:

```swift
// Version 1 encrypted with FMK + random nonce
let v1 = try AES.GCM.seal(document_v1, using: fmk, nonce: nonce_v1)

// Version 2 encrypted with same FMK + different random nonce
let v2 = try AES.GCM.seal(document_v2, using: fmk, nonce: nonce_v2)

// Result: v1.ciphertext ≠ v2.ciphertext (even if document content identical)
```

**Benefit**: Server cannot detect if versions have similar content (no correlation attacks).

### Access Revocation

When user is revoked from Emma's records:

1. **FMK rotation** creates new FMK_Emma_v2
2. **Re-encrypt current versions** with FMK_Emma_v2
3. **Historical versions** remain encrypted with old FMK_Emma_v1

**Result**: Revoked user can still read historical versions they had access to when active (acceptable - matches real-world custody record sharing).

**Alternative (if history must be revoked)**: Re-encrypt all versions, but expensive for large histories.

---

## API Examples

### Create New Record

```http
POST /api/records
Authorization: Bearer {jwt}

{
  "family_member_id": "uuid-emma",
  "record_type": "vaccination",
  "document": {
    "vaccine_name": "Pfizer COVID-19",
    "date_administered": "2024-03-16",
    ...
  },
  "change_summary": "Initial entry"
}

Response: {
  "record_id": "uuid-123",
  "version": 1
}
```

### Update Existing Record

```http
PUT /api/records/{record_id}
Authorization: Bearer {jwt}

{
  "document": {
    "vaccine_name": "Pfizer COVID-19",
    "date_administered": "2024-03-16",
    "attachments": ["uuid-attachment-789"]  // Added photo
  },
  "change_summary": "Attached vaccine card photo"
}

Response: {
  "record_id": "uuid-123",
  "version": 2
}
```

### Fetch Current State

```http
GET /api/family-members/{family_member_id}/records?type=vaccination
Authorization: Bearer {jwt}

Response: {
  "records": [
    {
      "record_id": "uuid-123",
      "version": 2,
      "document": { ... },
      "created_at": "2025-12-20T10:15:00Z",
      "created_by": "You (iPhone)"
    }
  ]
}
```

### Fetch History

```http
GET /api/records/{record_id}/history
Authorization: Bearer {jwt}

Response: {
  "versions": [
    {
      "version": 2,
      "document": { ... },
      "created_at": "2025-12-20T10:15:00Z",
      "change_summary": "Attached vaccine card photo",
      "is_current": true
    },
    {
      "version": 1,
      "document": { ... },
      "created_at": "2025-12-20T09:00:00Z",
      "change_summary": "Initial entry",
      "is_current": false
    }
  ]
}
```

### Restore Previous Version

```http
POST /api/records/{record_id}/restore
Authorization: Bearer {jwt}

{
  "target_version": 1
}

Response: {
  "record_id": "uuid-123",
  "new_version": 3,
  "message": "Restored from version 1"
}
```

---

## Comparison to Alternatives

| Approach | Data Loss Risk | User Control | Storage Cost | Implementation Complexity |
|----------|---------------|--------------|--------------|--------------------------|
| **Last-write-wins (no logging)** | ❌ High | ❌ None | ✅ Minimal | ✅ Simple |
| **Conflict detection + logging** | ⚠️ Medium (logged but lost) | ⚠️ Limited | ✅ Minimal | ⚠️ Moderate |
| **CRDTs (auto-merge)** | ✅ None | ❌ None (auto) | ⚠️ Moderate | ❌ Complex |
| **Wiki-style versioning** | ✅ **None** | ✅ **Full** | ⚠️ Moderate | ✅ **Simple** |

**Chosen**: Wiki-style versioning balances simplicity, user control, and zero data loss.

---

## References

- Issue #48 - Design conflict resolution strategy with data loss prevention
- ADR-0004 - Sync encryption and multi-device support
- `docs/technical/sync-implementation-details.md` - Sync implementation guide
- `docs/technical/s3-backend-design.md` - S3 backend architecture

---

## Decision Log

**2025-12-22**: Design accepted based on PR #43 review discussion
**Rationale**: Eliminates all conflict scenarios, provides familiar Wikipedia-like UX, storage cost negligible for medical records, simpler than CRDT-based approaches
