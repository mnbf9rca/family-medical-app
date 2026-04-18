# Day 1 Review: Ready to Fix (2026-04-18)

> **For Claude:** Use `superpowers:writing-plans` to create an implementation plan from this spec. The 30 findings below span multiple concerns and are too large for a single PR — the plan should group them into coherent, independently-reviewable PRs. Suggested grouping is noted at the bottom.

**Goal:** Remove structural debt identified by day-1-review, with all user decisions resolved. Every fix below has confidence ≥ 4 or an explicit user call.

**Scope:** iOS Swift app, backend-rust OPAQUE worker, backend/ TypeScript placeholder, ADRs, `.gitignore`s.

---

## Auth / Crypto cluster

### Finding 1: Remove legacy password+salt authentication path

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:88,129,141-143,338-345,372-378`
- **Evidence:** `useOpaqueKey` UserDefaults flag, `deriveCandidateKey` branches on `usesOpaque`, `deriveKeyViaLegacy(passwordBytes:)` method, `saltKey` storage. `completeLocalSetup` always sets `useOpaqueKey = true`; no remaining code path writes a legacy salt for auth. Direct AGENTS.md day-1-correctness violation ("no dual code paths; delete old code").
- **Fix:** Delete `useOpaqueKey`, `saltKey`, `usesOpaque`, `deriveKeyViaLegacy`, and the `useOpaque` branch in `deriveCandidateKey`. Simplify `isSetUp` to check only OPAQUE setup state (rolls in finding #9). Update tests that exercised the legacy path — remove them rather than adapt.
- **Verification:** Build + `scripts/run-tests.sh`. Grep for `useOpaque`, `saltKey`, `Legacy` in `Services/Auth/` returns zero matches. `scripts/check-coverage.sh` passes.

### Finding 2: Remove legacy password-setup state and `setUp()` from AuthenticationViewModel

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/ViewModels/Auth/AuthenticationViewModel.swift:23-58,161-208`
- **Evidence:** MARK sections `// Password Setup State (legacy, kept for backward compatibility)` and `// Setup Actions (legacy - kept for tests)`. OPAQUE flow uses `passphrase`/`confirmPassphrase` exclusively. `setUp()` has no production call site — only `AuthenticationViewModelSetupTests` calls it.
- **Fix:** Delete `password`, `confirmPassword`, `hasAttemptedSetup`, `hasConfirmFieldLostFocus`, `passwordStrength`, `passwordValidationErrors`, `displayedValidationErrors`, `shouldShowPasswordMismatch`, and `setUp()`. Delete `AuthenticationViewModelSetupTests.swift`. Remove `password`/`confirmPassword` clearing in `clearSensitiveFields()` and `logout()`.
- **Verification:** Build + tests pass. UI flow: create account → passphrase creation → biometric setup → home. No `password` field references remain in `ViewModels/Auth/`.

### Finding 3: Remove legacy 32-byte OPAQUE export key acceptance

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:82-87`, `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:357-362,420-425`
- **Evidence:** `guard exportKey.count == 32 || exportKey.count == 64`. opaque-ke with Sha512 always yields 64-byte export keys. Only `AuthenticationServiceExportKeyTests.setUpAccepts32ByteExportKey` exercises the 32-byte branch.
- **Fix:** Tighten validation to `exportKey.count == 64` everywhere. Delete the `setUpAccepts32ByteExportKey` test.
- **Verification:** Build + tests pass. Grep for `== 32` in auth/crypto returns nothing relevant.

### Finding 4: Document the production API base URL default

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift:25-27`
- **Evidence:** `defaultBaseURL = URL(string: "https://api.recordwell.app/auth/opaque")!` with no doc and no config-override mechanism. Force-unwrap of a compile-time literal is fine; the missing doc isn't.
- **Fix:** Add `///` doc above `defaultBaseURL` explaining: (a) this is the production endpoint, (b) override via `init(baseURL:)` for tests/staging, (c) a note that an xcconfig-based mechanism should be introduced before staging deployments exist. Leave the URL itself unchanged.
- **Verification:** Doc renders in Xcode quick-help. No functional change.

### Finding 5: Document the lock-timeout security default

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/LockStateService.swift:9,37`
- **Evidence:** `defaultTimeout = 300 // 5 minutes` — security-critical auto-lock default, no ADR/threat-model citation.
- **Fix:** Add `///` doc above `defaultTimeout` stating: the value (5 minutes), the threat model (inactive device left unattended), and the override path (`lockTimeoutSeconds` on the protocol). If there is an ADR covering session lifetime, link it; otherwise note that the rationale needs capturing.
- **Verification:** Doc renders. No functional change.

### Finding 6: Document the client-side rate-limit ladder

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:90-96`
- **Evidence:** `rateLimitThresholds: [(3,30),(4,60),(5,300),(6,900)]`. This is a *client-side* lockout ladder distinct from `backend-rust/src/rate_limit.rs` (Cloudflare-KV per-endpoint limits). Only the server numbers are in ADR-0011:167.
- **Fix:** Add `///` doc above `rateLimitThresholds` explaining: (a) this is local post-wrong-passphrase lockout, *not* the server rate limiter, (b) the ladder shape (escalating lockouts), (c) a cross-reference to backend-rust rate_limit.rs so readers understand these are separate layers. Consider proposing an ADR-0011 addendum in a follow-up issue.
- **Verification:** Doc renders. No functional change.

### Finding 7: Consolidate DEBUG + Release OPAQUE test-bypass on `isUITesting`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift:394-405`
- **Evidence:** DEBUG branch returns `true` for `testuser` / `test_*` regardless of launch context; Release requires `UITestingHelpers.isUITesting`. Asymmetry is undocumented.
- **User decision:** Require `isUITesting` in both configs.
- **Fix:** Collapse the `#if DEBUG` block to a single gate: `username.isTestUsername && UITestingHelpers.isUITesting`. Remove the DEBUG branch entirely.
- **Verification:** `scripts/run-tests.sh` passes, including `DemoModeUITests` and `NewUserFlowUITests`. Unit tests that inject `MockOpaqueAuthService` are unaffected.

### Finding 8: Update `KeyDerivationService` protocol doc to reflect backup-only usage

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:6-17,18,34,56-80`
- **Evidence:** After finding #1 lands, the only production caller of `derivePrimaryKey(from:salt:)` is `BackupFileService`. Current protocol doc frames it as the primary-key derivation for accounts.
- **Fix:** Rewrite the protocol-level and method-level doc comments to reflect backup-password KDF semantics. Do not rename the protocol yet — that's a larger structural move worth a separate issue.
- **Verification:** Doc renders with accurate wording. Grep for "primary key" in the file shows only the symbol name where appropriate.

### Finding 9: Remove unreachable `saltKey` fallback in `isSetUp`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:127-130`
- **Evidence:** `isSetUp` ORs `useOpaqueKey` with `saltKey` presence; no current code writes `saltKey` for auth setup. Rolls into finding #1.
- **Fix:** Reduce to `var isSetUp: Bool { userDefaults.bool(forKey: Self.useOpaqueKey) }`. (If finding #1 removes `useOpaqueKey` in favor of an OPAQUE-specific setup marker, align on that name.)
- **Verification:** Build + tests. No existing installations affected — pre-release app.

### Finding 10: Rewrite stale "new users vs existing" doc on `derivePrimaryKey`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:6-17`
- **Evidence:** Current doc says "salt: 16-byte salt (generate new for new users, retrieve for existing)". That semantic belongs to the deleted auth path. Backup now reads the salt from the export envelope.
- **Fix:** Update the `salt:` parameter doc to describe backup-export semantics (generate-on-export, stored in envelope, read-on-import). Absorb into finding #8 edit.
- **Verification:** Doc reads correctly; no functional change.

---

## Backend cluster

### Finding 11: Delete the `backend/` TypeScript placeholder Worker

- **Files:** `backend/src/index.ts`, `backend/README.md`, `backend/package.json`, `backend/wrangler.toml`, `backend/tsconfig.json`, `backend/.gitignore`, `backend/package-lock.json` (if tracked)
- **Evidence:** 43-line Worker returning 410 for `/auth/opaque/*` (pre-release app; no caller ever saw the TS endpoint) and 404 elsewhere. README and file header self-identify as placeholder. Phase 2 sync work is still planning (#13).
- **Fix:** Remove the entire `backend/` directory. Check for Cloudflare routing config tying `api.recordwell.app/*` to this Worker — if any remains, delete or redirect during deploy. If `.github/workflows/` references `backend/`, update or remove.
- **Verification:** `find backend -type f` returns nothing. CI still passes (check `.github/workflows/` specifically for any `backend/` job). Repo builds.

### Finding 12: Remove `serialize_server_setup` and its `#[allow(dead_code)]`

- **Files:** `backend-rust/src/opaque.rs:40-43`
- **Evidence:** Only `#[allow(dead_code)]` in the Rust codebase. Function has zero callers. `generate_setup.rs` has its own inline implementation. AGENTS.md forbids suppressing warnings instead of fixing root cause.
- **Fix:** Delete the function and the attribute.
- **Verification:** `cargo build` in `backend-rust/` with no warnings. `cargo test` passes.

### Finding 13: Document the OPAQUE wire-contract DTOs

- **Files:** `backend-rust/src/routes.rs:10,17,23,30,36,43,50,58,65`
- **Evidence:** 9 `pub struct`s define the HTTP contract with iOS `OpaqueAuthService`. All are `serde(rename_all = "camelCase")` with base64 fields; no `///` docs describing field semantics, base64 vs plain, or expected lengths. Schema is hand-synced between languages.
- **User decision:** Fix — add docs.
- **Fix:** Add `///` doc comments above each struct. Minimum requirement: which endpoint it belongs to, whether fields are base64-encoded opaque-ke blobs or plain identifiers, expected lengths (e.g., `client_identifier` is 64 hex chars = 32-byte SHA256). Cross-reference ADR-0011 section for the protocol flow.
- **Verification:** `cargo doc` renders. Reviewer can understand each field without reading opaque-ke or the iOS client.

### Finding 14: Remove unused `hex` dependency from `backend-rust/Cargo.toml`

- **Files:** `backend-rust/Cargo.toml:21`
- **Evidence:** `hex = "0.4"`. Grep confirms zero `use hex` / `hex::` in `backend-rust/`. Only match is an inline comment.
- **Fix:** Delete the line. Regenerate `Cargo.lock` (`cargo update --workspace` or `cargo build`).
- **Verification:** `cargo build` passes. `cargo tree` shows `hex` only as a transitive dep if at all.

---

## Views / UI cluster

### Finding 15: Remove spurious `import UIKit` in CameraCaptureController

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/Camera/CameraCaptureController.swift:3`
- **Evidence:** No `UI*` symbols referenced. AVFoundation + Foundation + CoreGraphics (via AVFoundation) cover used APIs.
- **Fix:** Delete the `import UIKit` line.
- **Verification:** Build succeeds.

### Finding 16: Remove spurious `import UIKit` in ThumbnailDisplayMode

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/ThumbnailDisplayMode.swift:1`
- **Evidence:** Enum uses only String/Data/Bool. Foundation suffices.
- **Fix:** Replace `import UIKit` with `import Foundation` (or remove if no Foundation types either — confirm with Read).
- **Verification:** Build succeeds.

### Finding 17: Merge `SettingsViewPreviewHelpers.swift` into `SettingsView.swift`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Settings/SettingsViewPreviewHelpers.swift`, `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Settings/SettingsView.swift`, `scripts/check-coverage.sh:104`
- **Evidence:** Split file wrapped in `#if DEBUG`, contains `#Preview` + four preview stubs. Carries a 0.0 coverage exception solely to pass the per-file threshold.
- **Fix:** Move the contents into a `#if DEBUG` block at the tail of `SettingsView.swift`. Delete `SettingsViewPreviewHelpers.swift`. Remove the coverage exception for `SettingsViewPreviewHelpers.swift` from `scripts/check-coverage.sh`.
- **Verification:** Build + `scripts/run-tests.sh` + `scripts/check-coverage.sh` all pass. Xcode preview for `SettingsView` still renders.

### Finding 18: Delete stale `TODO(#127)` in MedicalRecordListViewModel

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/ViewModels/Records/MedicalRecordListViewModel.swift:105`
- **Evidence:** `// TODO(#127): sort by clinical event date`. Issue #127 is CLOSED. Sort at line 108 uses `record.createdAt`.
- **User decision:** Delete the TODO.
- **Fix:** Remove the single TODO comment line. Leave the sort implementation unchanged.
- **Verification:** Grep for `TODO(#127)` in `ios/` returns nothing.

### Finding 19: Document `DocumentBlobService` size/thumbnail limits

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Document/DocumentBlobService.swift:82,83`
- **Evidence:** `maxFileSizeBytes = 10 * 1_024 * 1_024` and `thumbnailDimension = 200`. No doc comment.
- **Fix:** Add `///` above each constant. For `maxFileSizeBytes`: state the 10 MB cap, note that this is user-facing via `ModelError.documentTooLarge`, and the rationale (memory budget for Core Data blob + sync payload). For `thumbnailDimension`: note 200 pt (not px — respects @2x/@3x), and the purpose (list views, low decode cost).
- **Verification:** Doc renders. No functional change.

### Finding 20: Name the CameraCaptureView focus-indicator timing constants

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/Camera/CameraCaptureView.swift:240,242,243,252`
- **Evidence:** `Task.sleep(nanoseconds: 600_000_000)` alongside inline `0.25` and `0.15` animation durations in three places. No named constants.
- **Fix:** Introduce three private `static let` constants at the top of the view (or nearest enclosing type): `focusIndicatorVisibleDuration: Duration = .milliseconds(600)`, `focusFadeInDuration: TimeInterval = 0.25`, `focusFadeOutDuration: TimeInterval = 0.15`. Replace call sites. Switch the sleep to `Task.sleep(for: focusIndicatorVisibleDuration)` (iOS 16+ API; deployment target is 17.6).
- **Verification:** Build + UI smoke test on simulator: focus indicator appears, holds, fades as before.

---

## Models / Repos cluster

### Finding 21: Consolidate `trimmedNonEmpty` into a shared `String?` extension

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Models/Backup/PersonBackup.swift:66-72`, `ios/FamilyMedicalApp/FamilyMedicalApp/Models/Backup/ProviderBackup.swift:86-92`
- **Evidence:** Identical private funcs. New FHIR backup types will copy the pattern if left.
- **Fix:** Add `ios/FamilyMedicalApp/FamilyMedicalApp/Extensions/OptionalString+Trimming.swift` (or similar) with an internal `extension Optional where Wrapped == String { func trimmedNonEmpty() -> String? }`. Replace both private implementations with calls to it. Update call sites to the new form.
- **Verification:** Build + `scripts/run-tests.sh`. `BackupModelsTests` and `BackupEntityTests` pass. Coverage on the new extension is ≥85% (test through the two existing backup test suites or add a targeted extension test).

### Finding 22: Rename `personID` → `personId` in repository private helpers

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Repository/PersonRepository.swift:157,160,165`, `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Provider/ProviderRepository.swift:221,223`
- **Evidence:** `personId` in 76 files (dominant). `personID` only in two private `ensureFMK(for personID:)` helpers. `userID`/`userId` and `recordID`/`recordId` show same drift — confirm counts during fix and align the minority spellings.
- **Fix:** Rename all `personID` / `recordID` / `userID` occurrences to `personId` / `recordId` / `userId`. Update callers. Use Xcode's "Rename" refactor where available, otherwise ast-grep per AGENTS.md (**never** sed).
- **Verification:** Build + `scripts/run-tests.sh`. Grep for `personID`, `recordID`, `userID` in `ios/` returns zero matches (outside of any crypto-layer rename handled by finding #23).

### Finding 23: Rename `familyMemberID` → `personId` across FMK APIs and callers

- **Files:**
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/FamilyMemberKeyService.swift:32,40,80,98`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Repository/PersonRepository.swift:160,165,222`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Provider/ProviderRepository.swift:223`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Document/DocumentBlobService.swift:150,193`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Records/DocumentReferenceQueryService.swift:117`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Backup/ImportService.swift:77`
  - `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Backup/ExportService.swift:103`
- **Evidence:** Service exposes `storeFMK(familyMemberID:)`, `retrieveFMK(familyMemberID:)`, etc. Every caller passes `person.id.uuidString`. Keychain identifiers are `fmk.<id>`. The entity *is* `Person`.
- **User decision:** Fix — rename to `personId`.
- **Fix:** Rename all `familyMemberID:` labels and `familyMemberID` locals in `FamilyMemberKeyService` and `KeychainError.keyNotFound(_:)` to `personId`. The service class name (`FamilyMemberKeyService`) can stay — FMK is "Family Member Key", and renaming the service would be a larger structural move. Keychain storage key format `fmk.<id>` is preserved (the scheme name references the key, not the holder — unchanged behavior). Update all call sites. Update tests.
- **Verification:** Build + `scripts/run-tests.sh`. Grep for `familyMemberID` returns zero matches in `ios/FamilyMedicalApp/`. Existing keychain entries continue to resolve (since the storage format is unchanged).

### Finding 24: Document `ProviderRepository.ensureFMK` error-flattening invariant

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Provider/ProviderRepository.swift:221-227`
- **Evidence:** `PersonRepository.ensureFMK` distinguishes `keyNotFound` (generate new) from other errors. `ProviderRepository.ensureFMK` flattens all to `keyNotAvailable`. Comment captures the intent but the error message hides the real failure mode.
- **Fix:** Add a `///` doc on `ensureFMK` stating the invariant ("providers always belong to an existing Person; the FMK must pre-exist — any failure here indicates an upstream bug or keychain corruption"). Either (a) propagate the underlying error type via `RepositoryError.keyNotAvailable(underlying: Error)`, or (b) log the original error via `logger` before wrapping. Prefer (b) for a doc-first fix.
- **Verification:** Build + tests. When triggered in a test harness with a seeded keychain failure, the log contains the original error.

---

## Docs / Meta cluster

### Finding 25: Delete `docs/adr/examples/key-hierarchy-poc.swift` — contradicts ADR-0002

- **Files:** `docs/adr/examples/key-hierarchy-poc.swift`
- **Evidence:** Uses PBKDF2 (100k iters) + CommonCrypto. ADR-0002 explicitly rejects this approach in favor of Argon2id + Swift-Sodium; AGENTS.md Quick Reference forbids custom crypto. File is not referenced by any ADR (the three `docs/research/poc-*.swift` files are the cited examples).
- **Fix:** Delete the file. If the parent `docs/adr/examples/` directory becomes empty, delete it too.
- **Verification:** `find docs -name "key-hierarchy-poc.swift"` returns nothing. Grep for `CommonCrypto` in `docs/` returns nothing.

### Finding 26: Remove Python-only rules from root `.gitignore`

- **Files:** `.gitignore:42-46,62-64`
- **Evidence:** `.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.coverage`, `htmlcov/`. Zero `*.py` files in the repo.
- **Fix:** Delete lines 42-46 (entire "Backend (Phase 2)" Python block) and the Python-specific lines under "Testing".
- **Verification:** `git check-ignore` still correctly ignores the real artifacts (DerivedData, build, xcuserdata, etc.).

### Finding 27: Remove unused tool rules from `ios/.gitignore`

- **Files:** `ios/.gitignore:67,70-71,80-83,95`
- **Evidence:** Carthage/Build/, Dependencies/ + .accio/, fastlane/*, iOSInjectionProject/. Project uses SPM only; AGENTS.md confirms.
- **Fix:** Delete those lines (and their section headers where they become empty).

### Finding 28: Remove Xcode 3/4/8-compatibility patterns from both `.gitignore`s

- **Files:** `.gitignore:5,6,9,11-17`, `ios/.gitignore:9-22`
- **Evidence:** Self-labelled in `ios/.gitignore` as "Compatibility with Xcode 8 and earlier" / "Xcode 3 and earlier". Project requires Xcode 26.2+.
- **Fix:** Delete the patterns (`*.xcscmblueprint`, `*.xccheckout`, `*.pbxuser`, `*.mode1v3`, `*.mode2v3`, `*.perspectivev3`, `*.moved-aside`) and their comment blocks from both files.

### Finding 29: Consolidate `.gitignore`s — delete `ios/.gitignore`, fold unique rules into root

- **Files:** `.gitignore`, `ios/.gitignore`
- **Evidence:** ~90% overlap (xcuserdata, DerivedData, build, *.dSYM,*.hmap, *.ipa, playground.xcworkspace, .build/, etc.). Root `.gitignore` already covers `ios/`. `ios/.gitignore` has a few unique rules (e.g., `*/coverage.json`) that should be preserved at the root.
- **Fix:** After findings #26-#28, diff the two files. Merge any residual-unique rules from `ios/.gitignore` into root `.gitignore` (under clearly-labelled sections). Delete `ios/.gitignore`. Do the same check for `backend/.gitignore` (since finding #11 deletes `backend/`) and `opaque-swift/.gitignore` (confirm whether opaque-swift is its own Package/workspace and warrants a local ignore; likely yes — leave it alone if so).
- **Verification:** `git status` shows no newly-ignored-or-un-ignored files. `git check-ignore -v` for a few sample paths (DerivedData, .build, *.ipa) still resolves against root.

### Finding 30: Align coverage-threshold docs — update ADR-0006 README summary

- **Files:** `docs/adr/README.md:71`, potentially `docs/adr/adr-0006-test-coverage-requirements.md`
- **Evidence:** AGENTS.md: "Overall project coverage: 85% minimum (temporarily reduced from 90% for OPAQUE auth, see Issue #78)". README.md:71: "90% overall project coverage minimum, 85% per-file minimum".
- **Fix:** Update README.md:71 to reflect the current temporary threshold (85%) with a reference to Issue #78 and a note that it returns to 90% when #78 resolves. Read ADR-0006 body; if it too says 90%, add a postscript or status note rather than editing the historical decision text (same ADR-immutability convention applied to ADR-0009).
- **Verification:** Both surfaces report consistent numbers.

---

## Suggested PR grouping for `writing-plans`

A single PR for 30 findings is too big. Reasonable splits:

1. **Auth legacy removal** (findings 1, 2, 3, 9) — bundle; they share the same setup/unlock paths and need to land atomically so nothing is left half-migrated.
2. **Auth documentation** (findings 4, 5, 6, 8, 10) — doc-only, one PR.
3. **OPAQUE test-bypass consolidation** (finding 7) — tiny, its own PR (security-relevant).
4. **Backend Rust cleanup** (findings 12, 13, 14) — one PR.
5. **Delete `backend/` TS Worker** (finding 11) — one PR.
6. **Views spurious imports + constants + preview consolidation** (findings 15, 16, 17, 20) — one PR.
7. **Stale TODO + DocumentBlobService docs** (findings 18, 19) — one PR.
8. **Backup helpers + ID naming sweep** (findings 21, 22, 23, 24) — one PR (they all touch shared Person/Provider repository code).
9. **Docs + `.gitignore` cleanup** (findings 25, 26, 27, 28, 29, 30) — one PR.

CI runtime on this repo is ~6-8 minutes per PR; 9 PRs ≈ 1 hour of CI. Happy to adjust the split.
