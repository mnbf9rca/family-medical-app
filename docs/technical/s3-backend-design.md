# Pure Storage Backend Design (S3/MinIO)

## Overview

This document describes how to implement sync encryption using "pure storage" backends - blob storage systems with no database, no queries, and no server logic. Examples: AWS S3, Cloudflare R2, self-hosted MinIO.

**Key insight**: Instead of querying a database, use **deterministic object keys** and HEAD requests to check existence.

## Benefits

- ✅ **No database**: No Postgres, no migrations, no schema changes
- ✅ **No server code**: No API layer, no business logic, just storage
- ✅ **Self-hosted friendly**: Run MinIO in Docker (`docker run minio/minio server /data`)
- ✅ **Extremely cheap**: S3/R2 pricing is ~$0.02/GB/month
- ✅ **Battle-tested**: S3 API is industry standard, highly reliable
- ✅ **No maintenance**: Storage service handles redundancy, backups

## Trade-Offs

- ⚠️ **Polling-based sync**: 30-60 sec delay (no Realtime WebSocket)
- ⚠️ **More complex client**: Client coordinates sync (not server)
- ⚠️ **Manifest contention**: Multiple devices updating manifest simultaneously

## Object Key Structure

All data stored as blobs with deterministic keys:

```
Bucket: family-medical-app

/users/{user-id}/primary-key.blob
├─ Encrypted Primary Key (encrypted with recovery code)

/users/{user-id}/public-key.blob
├─ User's Curve25519 public key (plaintext, for key exchange)

/users/{user-id}/family-members/{fm-id}/profile.blob
├─ Family member profile (name, birthdate, relationship) - encrypted

/users/{user-id}/family-members/{fm-id}/records/{record-id}.v{version}.blob
├─ Medical record (encrypted with FMK)
├─ Multiple versions for conflict resolution

/users/{user-id}/family-members/{fm-id}/attachments/{hmac}/data.blob
├─ Attachment binary data (encrypted with FMK)

/users/{user-id}/family-members/{fm-id}/attachments/{hmac}/metadata.blob
├─ Attachment metadata (MIME type, filename, size) - encrypted

/users/{user-id}/access-grants/{grant-id}.blob
├─ Wrapped FMKs for sharing (encrypted with ECDH keys)

/users/{user-id}/devices/{device-id}.json
├─ Device metadata (device name, last seen) - plaintext

/users/{user-id}/sync-manifest.json
├─ Critical: Lists all changes with timestamps for sync coordination
```

## Sync Manifest Format

**Purpose**: Client downloads manifest to determine what's changed since last sync.

```json
{
  "version": 42,
  "last_updated": "2025-01-20T14:32:00Z",
  "changes": [
    {
      "type": "record",
      "family_member_id": "emma-uuid",
      "record_id": "rec-123",
      "version": 5,
      "timestamp": "2025-01-20T14:30:00Z",
      "device_id": "iphone-uuid",
      "action": "insert"
    },
    {
      "type": "attachment",
      "family_member_id": "emma-uuid",
      "attachment_hmac": "a3f2b945...",
      "timestamp": "2025-01-20T14:31:00Z",
      "device_id": "iphone-uuid",
      "action": "insert"
    },
    {
      "type": "record",
      "family_member_id": "liam-uuid",
      "record_id": "rec-456",
      "version": 3,
      "timestamp": "2025-01-20T14:32:00Z",
      "device_id": "ipad-uuid",
      "action": "update"
    }
  ]
}
```

**Client uses manifest to:**

1. Identify new/changed objects since last sync
2. Download only changed objects (delta sync)
3. Detect conflicts (multiple versions of same record)

## Sync Algorithm

### Full Sync Flow

```swift
func syncWithS3() async throws {
    // 1. Download sync manifest
    let manifest = try await s3.getObject(key: "/users/\(userId)/sync-manifest.json")
    let serverManifest = try JSONDecoder().decode(SyncManifest.self, from: manifest)

    // 2. Compare with local manifest (what's new?)
    let localManifest = loadLocalManifest()
    let newChanges = serverManifest.changes.filter { change in
        change.timestamp > localManifest.last_updated
    }

    // 3. Download new/changed objects
    for change in newChanges {
        switch change.type {
        case "record":
            let key = "/users/\(userId)/family-members/\(change.family_member_id)/records/\(change.record_id).v\(change.version).blob"
            let blob = try await s3.getObject(key: key)
            await saveLocalRecord(blob, decryptWith: getFMK(change.family_member_id))

        case "attachment":
            let dataKey = "/users/\(userId)/family-members/\(change.family_member_id)/attachments/\(change.attachment_hmac)/data.blob"
            let metadataKey = "/users/\(userId)/family-members/\(change.family_member_id)/attachments/\(change.attachment_hmac)/metadata.blob"

            // Check if already have this attachment
            if !localDB.hasAttachment(hmac: change.attachment_hmac) {
                let data = try await s3.getObject(key: dataKey)
                let metadata = try await s3.getObject(key: metadataKey)
                await saveLocalAttachment(data, metadata, decryptWith: getFMK(change.family_member_id))
            }
        }
    }

    // 4. Upload local changes
    let localChanges = await getLocalChanges(since: localManifest.last_updated)
    for change in localChanges {
        try await uploadChange(change)
    }

    // 5. Update local manifest
    saveLocalManifest(serverManifest)
}

// Poll every 30-60 seconds
func startSyncPolling() {
    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
        Task {
            try await syncWithS3()
        }
    }
}
```

### Attachment Deduplication

```swift
func uploadAttachment(data: Data, metadata: AttachmentMetadata, fmk: SymmetricKey, familyMemberId: UUID) async throws -> String {
    // Compute HMAC
    let hmac = HMAC<SHA256>.authenticationCode(for: data, using: fmk)
    let hmacString = hmac.compactMap { String(format: "%02x", $0) }.joined()

    // Check if exists (HEAD request)
    let dataKey = "/users/\(userId)/family-members/\(familyMemberId)/attachments/\(hmacString)/data.blob"
    let exists = try await s3.headObject(key: dataKey) // Returns 200 if exists, 404 if not

    if exists {
        // Reuse existing attachment ✅
        return hmacString
    } else {
        // Upload new attachment
        let encrypted = try encryptAttachment(data: data, metadata: metadata, fmk: fmk)

        try await s3.putObject(key: dataKey, body: encrypted.encryptedData)
        try await s3.putObject(
            key: "/users/\(userId)/family-members/\(familyMemberId)/attachments/\(hmacString)/metadata.blob",
            body: encrypted.encryptedMetadata
        )

        return hmacString
    }
}
```

### Conflict Resolution (Last-Write-Wins)

```swift
// When multiple versions exist
let versionsKey = "/users/\(userId)/family-members/\(fmId)/records/\(recordId)"
let allVersions = try await s3.listObjects(prefix: versionsKey) // Returns: [v1.blob, v2.blob, v3.blob]

// Download all versions
var newestVersion: MedicalRecord?
var newestTimestamp: Date?

for versionKey in allVersions {
    let blob = try await s3.getObject(key: versionKey)
    let record = try decryptRecord(blob, fmk: fmk)

    if newestTimestamp == nil || record.updated_at > newestTimestamp! {
        newestVersion = record
        newestTimestamp = record.updated_at
    }
}

// Keep newest, delete old versions
for versionKey in allVersions where versionKey != newestVersionKey {
    try await s3.deleteObject(key: versionKey)
}

// Save locally
await saveLocalRecord(newestVersion!)
```

## Manifest Contention Problem

**Problem**: Two devices upload changes simultaneously, both try to update manifest.

```
iPhone uploads record A → updates manifest (version 42)
iPad uploads record B → updates manifest (version 42) ← CONFLICT!
```

**Solution 1: Optimistic Locking with S3 ETags**

```swift
// Download manifest with ETag
let (manifest, etag) = try await s3.getObjectWithETag(key: manifestKey)

// Add local changes
var updatedManifest = manifest
updatedManifest.changes.append(newChange)
updatedManifest.version += 1

// Upload with condition: only if ETag matches
try await s3.putObject(
    key: manifestKey,
    body: updatedManifest,
    ifMatch: etag  // S3 rejects if ETag changed (another device updated)
)

// If rejected (409 Conflict):
// - Download latest manifest
// - Merge local changes
// - Retry upload
```

**Solution 2: Per-Device Manifests (Simpler)**

```
/users/{user-id}/devices/{device-id}/manifest.json  ← Each device writes own manifest
/users/{user-id}/sync-manifest.json                ← Merged view (optional)
```

**Client merges all device manifests:**

```swift
func syncWithS3() async throws {
    // 1. List all devices
    let devices = try await s3.listObjects(prefix: "/users/\(userId)/devices/")

    // 2. Download each device's manifest
    var allChanges: [Change] = []
    for deviceKey in devices {
        let manifest = try await s3.getObject(key: "\(deviceKey)/manifest.json")
        allChanges.append(contentsOf: manifest.changes)
    }

    // 3. Sort by timestamp (global ordering)
    allChanges.sort { $0.timestamp < $1.timestamp }

    // 4. Apply changes in order (last-write-wins)
    for change in allChanges {
        await applyChange(change)
    }

    // 5. Upload own manifest
    let ownManifest = createManifest(localChanges)
    try await s3.putObject(
        key: "/users/\(userId)/devices/\(deviceId)/manifest.json",
        body: ownManifest
    )
}
```

**Benefits:**

- ✅ No contention (each device writes own manifest)
- ✅ Simple conflict resolution (merge + sort)
- ⚠️ Multiple manifest downloads (acceptable, small files)

## Conflict Resolution Algorithm

For detailed conflict resolution design, see **[Wiki-Style Versioning](./wiki-style-versioning.md)**.

### Summary: Immutable Version History

Instead of "last-write-wins" conflict detection, the application uses **wiki-style immutable versioning**:

1. **Every edit creates a new version** (never modifies existing versions)
2. **All versions stored permanently** (append-only)
3. **Users can view history** and restore previous versions (like Wikipedia)
4. **Concurrent edits both succeed** - no conflicts, just history

### S3 Manifest Merge with Versioning

When merging manifests from multiple devices:

```swift
func mergeManifests(_ local: Manifest, _ remote: Manifest) -> Manifest {
    var merged = Manifest()

    // Union all record IDs
    let allRecordIds = Set(local.records.keys).union(remote.records.keys)

    for recordId in allRecordIds {
        let localVersion = local.records[recordId]?.currentVersion ?? 0
        let remoteVersion = remote.records[recordId]?.currentVersion ?? 0

        // Latest version wins as "current"
        let currentVersion = max(localVersion, remoteVersion)

        // Preserve all versions from both manifests
        let localVersions = local.records[recordId]?.allVersions ?? []
        let remoteVersions = remote.records[recordId]?.allVersions ?? []
        let allVersions = Set(localVersions).union(remoteVersions).sorted()

        merged.records[recordId] = RecordEntry(
            currentVersion: currentVersion,
            allVersions: allVersions
        )
    }

    return merged
}
```

### Benefits for S3 Backend

- ✅ **No data loss** - all versions from both devices preserved
- ✅ **Deterministic** - max(version) always wins as current
- ✅ **No tie-breaking needed** - version numbers are sequential
- ✅ **Audit trail** - full history stored in S3 objects

See [wiki-style-versioning.md](./wiki-style-versioning.md) for complete algorithm specification.

## Access Control

**Option 1: S3 IAM Policies (Complex)**

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::ACCOUNT:user/alice"},
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::family-medical-app/users/alice-uuid/*"
    }
  ]
}
```

**Problems:**

- Requires managing IAM users for each app user (complex)
- Sharing across users requires dynamic policy updates (complex)

**Option 2: Presigned URLs (Simple)**

Lightweight auth server (no database, stateless):

```swift
// Auth server (stateless)
POST /auth/login
  → Validate password (check Supabase or Auth0)
  → Return JWT token (includes userId claim)

GET /presigned-url/manifest
GET /presigned-url/records/{recordId}
GET /presigned-url/attachments/{attachmentId}
  → Validate JWT token
  → Extract userId from JWT claims
  → Derive object key from userId and resource type (server-side)
  → Generate presigned S3 URL for the derived key (expires in 1 hour)
  → Return URL to client

// Example: Manifest URL
GET /presigned-url/manifest
  → JWT contains: {"userId": "user-uuid-123"}
  → Server derives objectKey = "users/user-uuid-123/manifest.json"
  → Generates presigned URL for that specific object
  → Returns URL to client

// Client (userId is in JWT, not supplied by client)
let url = try await authServer.getPresignedURL(for: .manifest)
let manifest = try await URLSession.shared.data(from: url) // Direct S3 access
```

**Benefits:**

- ✅ Simple (auth server has no storage logic, just generates URLs)
- ✅ Secure (presigned URLs expire, scoped to specific objects)
- ✅ Tenant isolation (server derives object keys from JWT, prevents cross-user access)
- ✅ Works with any S3-compatible storage (MinIO, R2, S3)

## Self-Hosted Setup (MinIO)

**1. Run MinIO Server:**

```bash
docker run -p 9000:9000 -p 9001:9001 \
  -e "MINIO_ROOT_USER=admin" \
  -e "MINIO_ROOT_PASSWORD=secret123" \
  -v /mnt/data:/data \
  minio/minio server /data --console-address ":9001"
```

**2. Create Bucket:**

```bash
mc alias set myminio http://localhost:9000 admin secret123
mc mb myminio/family-medical-app
mc anonymous set none myminio/family-medical-app  # Private bucket
```

**3. Configure Client:**

```swift
let s3Config = S3Config(
    endpoint: "http://localhost:9000",
    accessKey: "admin",
    secretKey: "secret123",
    bucket: "family-medical-app"
)
```

**Total cost:** Free (self-hosted), or ~$5/month for VPS + storage.

## Comparison: Supabase vs. S3

| Feature | Supabase (Smart Backend) | S3/MinIO (Pure Storage) |
|---------|--------------------------|-------------------------|
| **Server Logic** | Yes (Postgres, RLS, Realtime) | No (just blob storage) |
| **Database** | Yes (Postgres) | No |
| **Real-time Sync** | Yes (WebSocket) | No (polling) |
| **Sync Delay** | Instant | 30-60 seconds |
| **Queries** | Yes (SQL) | No (key lookups only) |
| **Deduplication** | Database query | HEAD request |
| **Self-Hosted Setup** | Complex (Postgres, Realtime, RLS) | Simple (`docker run minio`) |
| **Maintenance** | Database migrations, schema changes | None (schema-less) |
| **Cost (1000 users, 100GB)** | ~$25/month (Supabase Pro) | ~$2/month (S3) or free (MinIO) |
| **Client Complexity** | Low (server does coordination) | Medium (client does coordination) |

**Recommendation:**

- **Phase 2-3**: Use Supabase (faster development, instant sync)
- **Phase 4 (optional)**: Add S3 backend support for self-hosted users

## Implementation Checklist

- [ ] S3 client library (AWS SDK or MinIO SDK)
- [ ] Manifest format (JSON schema)
- [ ] Sync polling loop (30-60 sec interval)
- [ ] Conflict resolution (last-write-wins with versioning)
- [ ] Attachment deduplication (HEAD request for HMAC)
- [ ] Per-device manifests (avoid contention)
- [ ] Presigned URL auth server (optional, for shared deployments)
- [ ] MinIO Docker setup guide
- [ ] Migration tool (Supabase → S3, if switching backends)

---

**Status**: Design complete (not yet implemented)
**Target**: Phase 4 (self-hosted option)
**Author**: Claude Code
**Date**: 2025-12-21

---

## UPDATED: Proxied Architecture (Recommended for Commercial Service)

### Architecture Decision: Cloudflare Worker Proxy

**Problem**: Public S3 buckets leak metadata (who has how much data, upload patterns) and enable offline attacks.

**Solution**: Proxy all access through Cloudflare Worker.

```
┌─────────────┐          ┌──────────────────┐          ┌─────────┐
│ iOS Client  │          │ Cloudflare Worker│          │   R2    │
│             │          │  (Auth + Proxy)  │          │  (or S3)│
└─────────────┘          └──────────────────┘          └─────────┘
      │                            │                          │
      │ GET /api/manifest.json     │                          │
      │ (Authorization: Bearer JWT)│                          │
      ├───────────────────────────>│ Validate JWT             │
      │                            │ Verify user can access   │
      │                            │ GET from R2              │
      │                            ├─────────────────────────>│
      │                            │ Encrypted blob           │
      │                            │<─────────────────────────┤
      │ Encrypted blob             │                          │
      │<───────────────────────────┤                          │
```

### Why Proxied > Presigned URLs?

| Benefit | Proxied | Presigned URLs |
|---------|---------|----------------|
| Backend migration | ✅ Change R2→S3, no app update | ❌ Requires app update |
| Client simplicity | ✅ Talks to `api.example.com` | ⚠️ Talks to `s3.amazonaws.com` |
| Caching | ✅ Worker caches manifests | ❌ No caching |
| Rate limiting | ✅ Built-in | ❌ Complex |
| Latency | ⚠️ +10-50ms (edge routing) | ✅ Direct S3 |

**Decision**: Proxied (flexibility > 10ms latency)

### Cloudflare Worker Code

```typescript
// ~150 lines, runs globally at edge
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    
    if (url.pathname === '/auth/login') {
      return handleLogin(request, env);
    }
    
    if (url.pathname.startsWith('/api/')) {
      return proxyToStorage(request, env);
    }
    
    return new Response('Not Found', { status: 404 });
  }
};

async function proxyToStorage(request: Request, env: Env): Promise<Response> {
  // Validate JWT
  const jwt = request.headers.get('Authorization')?.substring(7);
  const user = await validateJWT(jwt, env);
  if (!user) return new Response('Unauthorized', { status: 401 });
  
  // Extract path: /api/manifest.json → users/{user-id}/manifest.json
  const path = request.url.substring(5);  // Remove '/api/'
  const key = `users/${user.id}/${path}`;
  
  // Security: User can only access own data
  if (!key.startsWith(`users/${user.id}/`)) {
    return new Response('Forbidden', { status: 403 });
  }
  
  // Proxy to R2 (or switch to S3 here without client changes!)
  if (request.method === 'GET') {
    const object = await env.R2_BUCKET.get(key);
    return object ? new Response(object.body) : new Response('Not Found', { status: 404 });
  }
  
  if (request.method === 'PUT') {
    await env.R2_BUCKET.put(key, request.body);
    return new Response('Created', { status: 201 });
  }
  
  if (request.method === 'HEAD') {
    const object = await env.R2_BUCKET.head(key);
    return new Response(null, { status: object ? 200 : 404 });
  }
  
  return new Response('Method Not Allowed', { status: 405 });
}
```

### Costs (Commercial Service, 1000 users, 100GB)

- **Cloudflare Workers**: Free tier (100k requests/day) or $5/month (10M requests)
- **Cloudflare R2**: $1.50/month (100GB × $0.015/GB)
- **Total**: ~$2-7/month

Compare:

- Supabase Pro: $25/month
- AWS S3 + Lambda: ~$15/month

### Backend Migration Example

**Scenario**: Switch from R2 to Backblaze B2 (cheaper for bandwidth)

```typescript
// Before (R2)
const object = await env.R2_BUCKET.get(key);

// After (B2) - ONE LINE CHANGE
const object = await env.B2_CLIENT.downloadFileByName(key);

// Client code: UNCHANGED ✅
```

No app update needed. Users don't notice anything.

### Async Backup (YAGNI)

**Not implementing now**, but architecture supports it:

```typescript
// Write to primary
await env.R2_BUCKET.put(key, body);

// Async backup to S3 (don't block response)
env.waitUntil(backupToS3(key, body));
```

Separate backup worker replicates R2 → S3 asynchronously (eventual consistency).

---

**Status**: Proxied architecture is recommended for commercial deployment
**Date**: 2025-12-21
**Rationale**: Backend flexibility > 10ms latency cost
