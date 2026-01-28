# RecordWell Backend Deployment Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy the OPAQUE authentication backend to recordwell.app and update all domain references from family-medical.cynexia.com to recordwell.app.

**Architecture:** Cloudflare Workers on recordwell.app domain with KV storage for OPAQUE credentials, encrypted bundles, and login state. iOS app updated to point to new API endpoint.

**Tech Stack:**

- Cloudflare Workers (TypeScript)
- Cloudflare KV storage
- @serenity-kit/opaque (WASM-based OPAQUE protocol)
- Swift/SwiftUI iOS app

---

## Pre-Completed Setup (Already Done)

The following infrastructure has already been configured:

### KV Namespaces (Created)

| Binding | ID | Status |
|---------|-----|--------|
| `CREDENTIALS` | `c0373f3b95e54fbeaaef36782d426ca3` | ✅ Created |
| `BUNDLES` | `7967763b05c9496e89c4223fd765a34d` | ✅ Created |
| `LOGIN_STATES` | `671b81ebdc2946e494d0d37c2059f9d6` | ✅ Created |
| `RATE_LIMITS` | `5d519620a3c341bc8821fc568ce67beb` | ✅ Created |
| `CODES` | `ff2bfe3aeee2475a97caf1956b7644c7` | ⚠️ Legacy - to be removed |
| `USERS` | `77ae5a3875c14a9ab69c540bb3e12f4a` | ⚠️ Legacy - to be removed |

### Secrets

| Secret | Status |
|--------|--------|
| `recordwell_OPAQUE_SERVER_SETUP` | ✅ Stored in Cloudflare secrets store |

### Domain & DNS

| Item | Status |
|------|--------|
| recordwell.app zone in Cloudflare | ✅ Configured |
| apple-app-site-association | ✅ Deployed to `https://recordwell.app/.well-known/apple-app-site-association` |
| DNS propagation | ⏳ In progress |
| Wrangler CLI | ✅ Logged in |

---

## Remaining Tasks

### Task 1: Remove legacy email verification code

**Files:**

- Delete: `backend/src/email.ts`
- Modify: `backend/src/index.ts` (remove email routes and imports)
- Modify: `backend/package.json` (remove @aws-sdk/client-ses)

**Step 1: Delete email.ts**

```bash
rm backend/src/email.ts
```

**Step 2: Update index.ts**

Remove these imports from top of file:

```typescript
import { sendVerificationEmail, generateVerificationCode } from './email';
```

Remove from Env interface:

```typescript
  // Legacy email verification (to be removed)
  CODES: KVNamespace;
  USERS: KVNamespace;
  AWS_ACCESS_KEY_ID: string;
  AWS_SECRET_ACCESS_KEY: string;
  AWS_REGION: string;
  FROM_EMAIL: string;
```

Remove legacy types (SendCodeRequest, VerifyCodeRequest, StoredCode interfaces).

Remove CODE_TTL_SECONDS constant.

Remove legacy routes:

```typescript
      // Legacy email verification routes (to be removed)
      if (path === '/api/auth/send-code') {
        return handleSendCode(request, env);
      }
      if (path === '/api/auth/verify-code') {
        return handleVerifyCode(request, env);
      }
```

Remove handleSendCode and handleVerifyCode functions entirely.

**Step 3: Update package.json**

Remove from dependencies:

```json
"@aws-sdk/client-ses": "^3.975.0",
```

Update name and description:

```json
{
  "name": "recordwell-api",
  "description": "Cloudflare Workers backend for RecordWell OPAQUE authentication",
  "keywords": [
    "cloudflare-workers",
    "opaque",
    "authentication"
  ],
```

**Step 4: Reinstall dependencies**

```bash
cd backend && npm install
```

**Step 5: Verify TypeScript compiles**

```bash
cd backend && npm run typecheck
```

Expected: No errors

**Step 6: Commit cleanup**

```bash
git add backend/
git commit -m "chore(backend): remove legacy email verification code

Email verification replaced by OPAQUE zero-knowledge authentication:
- Remove email.ts (SES integration)
- Remove /api/auth/send-code and verify-code routes
- Remove @aws-sdk/client-ses dependency
- Rename to recordwell-api"
```

---

### Task 2: Update wrangler.toml for recordwell.app

**Files:**

- Modify: `backend/wrangler.toml`

**Step 1: Replace entire wrangler.toml contents**

```toml
name = "recordwell-api"
main = "src/index.ts"
compatibility_date = "2024-01-01"

# Routes
routes = [
  { pattern = "api.recordwell.app/*", zone_name = "recordwell.app" }
]

# KV Namespaces - OPAQUE Authentication
[[kv_namespaces]]
binding = "CREDENTIALS"
id = "c0373f3b95e54fbeaaef36782d426ca3"

[[kv_namespaces]]
binding = "BUNDLES"
id = "7967763b05c9496e89c4223fd765a34d"

[[kv_namespaces]]
binding = "LOGIN_STATES"
id = "671b81ebdc2946e494d0d37c2059f9d6"

[[kv_namespaces]]
binding = "RATE_LIMITS"
id = "5d519620a3c341bc8821fc568ce67beb"

[vars]
ENVIRONMENT = "production"

# Secrets (set with `wrangler secret put <NAME>`):
# - OPAQUE_SERVER_SETUP: stored as recordwell_OPAQUE_SERVER_SETUP in secrets store
```

**Step 2: Commit wrangler.toml update**

```bash
git add backend/wrangler.toml
git commit -m "build(backend): configure recordwell.app routes and KV namespaces"
```

---

### Task 3: Update backend README

**Files:**

- Modify: `backend/README.md`

**Step 1: Replace README.md contents**

```markdown
# RecordWell API

Cloudflare Workers backend for RecordWell app OPAQUE zero-knowledge authentication.

## Architecture

- **Cloudflare Workers** - Serverless API endpoints
- **Cloudflare KV** - OPAQUE password files, encrypted bundles, login state
- **@serenity-kit/opaque** - OPAQUE protocol (RFC 9807) implementation

## API Endpoints

### OPAQUE Authentication

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/opaque/register/start` | Begin registration |
| POST | `/auth/opaque/register/finish` | Complete registration |
| POST | `/auth/opaque/login/start` | Begin login |
| POST | `/auth/opaque/login/finish` | Complete login |

## Development

\`\`\`bash
npm install
npm run dev        # Local development
npm run typecheck  # Type checking
npm run deploy     # Deploy to production
\`\`\`

## Environment Variables

| Name | Description |
|------|-------------|
| `OPAQUE_SERVER_SETUP` | Secret: OPAQUE server setup string |

## KV Namespaces

| Binding | Purpose |
|---------|---------|
| `CREDENTIALS` | OPAQUE password files |
| `BUNDLES` | Encrypted user data bundles |
| `LOGIN_STATES` | Temporary login state (60s TTL) |
| `RATE_LIMITS` | Rate limit counters |
```

**Step 2: Commit README update**

```bash
git add backend/README.md
git commit -m "docs(backend): update README for RecordWell OPAQUE API"
```

---

### Task 4: Update iOS API endpoint

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift`

**Step 1: Update default base URL (line 18-19)**

Change:

```swift
private static let defaultBaseURL =
    URL(string: "https://family-medical.cynexia.com/api/auth/opaque")! // swiftlint:disable:this force_unwrapping
```

To:

```swift
private static let defaultBaseURL =
    URL(string: "https://api.recordwell.app/auth/opaque")! // swiftlint:disable:this force_unwrapping
```

**Step 2: Verify build succeeds**

```bash
cd ios/FamilyMedicalApp && xcodebuild -scheme FamilyMedicalApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 3: Commit iOS endpoint update**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift
git commit -m "feat(ios): update API endpoint to api.recordwell.app"
```

---

### Task 5: Update associated domains (remove cynexia.com)

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp/FamilyMedicalApp.entitlements`

**Step 1: Replace with recordwell.app only**

Change:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>webcredentials:family-medical.cynexia.com</string>
    <string>applinks:family-medical.cynexia.com</string>
    <string>applinks:recordwell.app</string>
    <string>webcredentials:recordwell.app</string>
</array>
```

To:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>webcredentials:recordwell.app</string>
    <string>applinks:recordwell.app</string>
</array>
```

**Step 2: Commit entitlements update**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalApp/FamilyMedicalApp.entitlements
git commit -m "build(ios): use recordwell.app for associated domains

Remove deprecated family-medical.cynexia.com references"
```

---

### Task 6: Deploy backend to Cloudflare Workers

**Step 1: Verify DNS has propagated**

```bash
dig api.recordwell.app
```

If no record exists yet, you may need to add a CNAME or let Workers create it.

**Step 2: Deploy**

```bash
cd backend && npx wrangler deploy
```

Expected output includes:

- Published recordwell-api
- Routes: `https://api.recordwell.app/*`

**Step 3: Verify deployment**

```bash
curl -X OPTIONS https://api.recordwell.app/auth/opaque/login/start -i
```

Expected: 204 with CORS headers

```bash
curl -X POST https://api.recordwell.app/auth/opaque/login/start \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier": "0000000000000000000000000000000000000000000000000000000000000000", "startLoginRequest": "test"}'
```

Expected: 401 (user doesn't exist) - confirms OPAQUE routes are working

---

### Task 7: Run iOS tests and verify

**Step 1: Run unit tests**

```bash
./scripts/run-tests.sh
```

Expected: All tests pass

**Step 2: Verify coverage**

```bash
./scripts/check-coverage.sh
```

Expected: Coverage meets thresholds

**Step 3: Commit and push**

```bash
git push -u origin update-associated-domain
```

**Step 4: Create PR**

```bash
gh pr create --title "Deploy RecordWell backend to recordwell.app" --body "$(cat <<'EOF'
## Summary
- Deploy OPAQUE authentication backend to api.recordwell.app
- Remove legacy email verification code
- Update iOS app to use new API endpoint
- Configure Cloudflare KV namespaces

## Changes
- Backend: Remove email.ts, update routes to recordwell.app
- iOS: Update OpaqueAuthService endpoint
- iOS: Prioritize recordwell.app in associated domains

## Test plan
- [ ] All unit tests pass
- [ ] UI tests pass
- [ ] Manual test: Register new user via API
- [ ] Manual test: Login existing user via API
- [ ] Verify apple-app-site-association accessible at recordwell.app
EOF
)"
```

---

## Summary

**7 tasks remaining** (infrastructure already configured):

| Task | Description | Files |
|------|-------------|-------|
| 1 | Remove legacy email code | `backend/src/email.ts`, `index.ts`, `package.json` |
| 2 | Update wrangler.toml | `backend/wrangler.toml` |
| 3 | Update backend README | `backend/README.md` |
| 4 | Update iOS API endpoint | `OpaqueAuthService.swift` |
| 5 | Update associated domains | `FamilyMedicalApp.entitlements` |
| 6 | Deploy to Cloudflare | `wrangler deploy` |
| 7 | Run tests and create PR | `run-tests.sh`, `gh pr create` |

**Key values:**

- New API endpoint: `https://api.recordwell.app/auth/opaque`
- Worker name: `recordwell-api`
- Secret: `recordwell_OPAQUE_SERVER_SETUP` (already in secrets store)
