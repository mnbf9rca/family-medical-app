# Day 1 Review: Detailed Findings (2026-04-18)

**Scope:** Full repo (`--all`), 438 tracked files. 5 Phase 3 Opus agents evaluated 28 candidates from three Phase 2 groups and surfaced 6 additional findings the graph missed.

## Subagent Issues & Recommendations

- **Phase 1 (graph extraction):** ctags has no Swift parser in Universal Ctags 6.2.1 — fell back to regex for 313 Swift files. Reference edges filter short/lowercase names to limit false positives. TOML parser reported broken (Cargo.toml symbols missed). POC Swift files under `docs/` produced false reference edges to real app code via common function names. All dead-code candidates were verified with a second targeted Grep.
- **Phase 2 Group B:** Stale-docs detection cannot run in `--all` mode (no diff). Orphaned-docs covered the analogous case.
- **Phase 2 Group A:** Dependency graph edges are file-level only (not symbol-level calls). Swift `@Observable` macro-generated code + protocol conformances are not modelled.
- **Phase 3 agents:** Largely corroborated mechanical candidates; produced 6 additional findings (auth residue, error-handling ambiguity, doc drift) and rejected 4 candidates as false positives (TracingCategoryLogger pass-through is justified; UITest XCTest split is documented; ADR-0009 orphan refs are a convention artifact; docs/research POCs serve their stated purpose).

---

## Findings

### Group 1: Auth/Crypto (10 findings)

#### 1. Legacy password+salt authentication path kept alongside OPAQUE

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:88,129,141-143,338-345,372-378`
- **Category:** backwards-compat-shim | **Type:** MacGyver
- **Impact:** 4/5 — actively misleads; two viable auth paths in a pre-release codebase
- **Confidence:** 5/5 — `completeLocalSetup` always sets `useOpaqueKey = true`; no remaining writer of legacy salt for auth
- **Contagion:** 3/5 — every new auth change must reason about both paths
- **Evidence:** `useOpaqueKey` UserDefaults flag, `deriveCandidateKey` branches on `usesOpaque`, `deriveKeyViaLegacy(passwordBytes:)` method and comments explicitly kept "for pre-OPAQUE accounts". Direct AGENTS.md day-1-correctness violation ("no dual code paths, delete old code when replacing", pre-release with no external consumers).
- **Recommendation:** Remove
- **Source:** b1

#### 2. Legacy password-setup state and `setUp()` action preserved on ViewModel for tests only

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/ViewModels/Auth/AuthenticationViewModel.swift:23-58,161-208`
- **Category:** dead-shim | **Type:** Local
- **Impact:** 3/5 — tests hold dead production fields alive
- **Confidence:** 5/5 — no production call site; OPAQUE flow uses `passphrase`/`confirmPassphrase` exclusively
- **Contagion:** 2/5
- **Evidence:** MARKs `// MARK: - Password Setup State (legacy, kept for backward compatibility)` and `// MARK: - Setup Actions (legacy - kept for tests)`. Only `AuthenticationViewModelSetupTests` calls `setUp()`. `password`/`confirmPassword` have no live UI binding.
- **Recommendation:** Remove (both the state and the tests that pin it)
- **Source:** b2

#### 3. Legacy 32-byte OPAQUE export key accepted alongside 64-byte

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:82-87`, `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:357-362,420-425`
- **Category:** backwards-compat-shim | **Type:** MacGyver
- **Impact:** 3/5
- **Confidence:** 4/5 — OPAQUE impl (opaque-ke with Sha512) always produces 64-byte export keys; only a specific mocked test exercises the 32-byte branch
- **Contagion:** 2/5
- **Evidence:** `guard exportKey.count == 32 || exportKey.count == 64` with comment "Accept both 32-byte (legacy) and 64-byte (current) keys", replicated in three places.
- **Recommendation:** Remove
- **What's unknown:** Whether any DEBUG-mode keychain entry from pre-release runs persists a 32-byte key — unlikely since export key is re-derived at each unlock (not stored).
- **Source:** b3

#### 4. Production API base URL hardcoded with force-unwrap, no config path

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift:25-27`
- **Category:** hidden-default-magic | **Type:** Foundational
- **Impact:** 3/5
- **Confidence:** 4/5
- **Contagion:** 2/5
- **Evidence:** `private static let defaultBaseURL = URL(string: "https://api.recordwell.app/auth/opaque")! // swiftlint:disable:this force_unwrapping`. Init allows DI override, but no xcconfig/Info.plist/env path exists.
- **Recommendation:** Document (or introduce xcconfig-based config if a staging switch is planned)
- **What's unknown:** Whether a config mechanism is planned — no scaffolding exists yet.
- **Source:** b7

#### 5. Lock timeout default 300s hardcoded with no security rationale

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/LockStateService.swift:9,37`
- **Category:** hidden-default-magic | **Type:** Foundational
- **Impact:** 2/5
- **Confidence:** 4/5
- **Contagion:** 3/5
- **Evidence:** `private static let defaultTimeout = 300 // 5 minutes`. Security-critical auto-lock value; no ADR or threat-model citation. Protocol permits override but no settings UI binds it.
- **Recommendation:** Document (add `///` citing the threat model or an ADR)
- **Source:** b8

#### 6. Auth rate-limit thresholds hardcoded with no ADR citation

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:90-96`
- **Category:** hidden-default-magic | **Type:** Foundational
- **Impact:** 3/5
- **Confidence:** 4/5
- **Contagion:** 2/5
- **Evidence:** `rateLimitThresholds: [(3,30),(4,60),(5,300),(6,900)]`. Client-side lockout ladder is *not* the same as backend-rust rate limiter (different layers: local post-wrong-password lockouts vs per-endpoint Cloudflare-KV limits). ADR-0011:167 documents server-side numbers; client numbers have no doc.
- **Recommendation:** Document
- **Source:** b9

#### 7. DEBUG branch in `shouldBypassForTestUsername` unconditionally bypasses OPAQUE

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift:394-405`
- **Category:** hidden-default-implicit | **Type:** Foundational
- **Impact:** 3/5
- **Confidence:** 3/5
- **Contagion:** 2/5
- **Evidence:** DEBUG returns `true` for `testuser` / `test_*` regardless of `isUITesting`. Release requires `UITestingHelpers.isUITesting`. Asymmetry is undocumented implicit behavior.
- **Recommendation:** Consolidate (gate both on `isUITesting`)
- **What's unknown:** Whether any DEBUG-only test depends on the unconditional bypass. Grep suggests not.
- **Source:** c11

#### 8. `derivePrimaryKey(from:salt:)` remains on KeyDerivationService only for backup path (stale protocol naming)

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:18,34,56-80`
- **Category:** hidden-default-implicit | **Type:** Local
- **Impact:** 2/5
- **Confidence:** 4/5
- **Contagion:** 2/5
- **Evidence:** After removing legacy auth, the only production caller is `BackupFileService`. Protocol name/doc still frames this as "primary key derivation for accounts".
- **Recommendation:** Document (or rename to `BackupKeyDerivationService` after finding #1 lands)
- **Source:** New (Phase 3)

#### 9. `isSetUp` falls back on a legacy `saltKey` that no current code writes

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift:127-130`
- **Category:** dead-shim | **Type:** Local
- **Impact:** 2/5
- **Confidence:** 4/5
- **Contagion:** 1/5
- **Evidence:** `var isSetUp: Bool { userDefaults.bool(forKey: Self.useOpaqueKey) || userDefaults.data(forKey: Self.saltKey) != nil }`. The `|| saltKey` branch is unreachable under current setup paths.
- **Recommendation:** Remove (rolls up into finding #1)
- **Source:** New (Phase 3)

#### 10. Stale doc comment on `derivePrimaryKey(from:salt:)` about "new users vs existing"

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Crypto/KeyDerivationService.swift:6-17`
- **Category:** stale-docs | **Type:** Local
- **Impact:** 1/5
- **Confidence:** 5/5
- **Contagion:** 1/5
- **Evidence:** Doc text "(generate new for new users, retrieve for existing)" describes pre-OPAQUE account setup semantics that no longer apply to the only remaining caller (BackupFileService).
- **Recommendation:** Document (rewrite for backup semantics)
- **Source:** New (Phase 3)

---

### Group 2: Backend (4 findings)

#### 11. TypeScript placeholder Worker is premature scaffolding

- **Files:** `backend/src/index.ts`, `backend/README.md`, `backend/package.json`, `backend/wrangler.toml`
- **Category:** premature-scaffolding | **Type:** MacGyver
- **Impact:** 2/5
- **Confidence:** 4/5
- **Contagion:** 3/5
- **Evidence:** 43-line Worker: returns 410 for `/auth/opaque/*` ("moved to Rust") and 404 elsewhere. Env declares four KV bindings, only RATE_LIMITS is mentioned (never read). README and header admit it's a placeholder. No one uses it. Phase 2 sync work is still planning (#13).
- **Recommendation:** Remove entire `backend/` dir — recreate when sync endpoints actually ship
- **What's unknown:** Whether `api.recordwell.app/*` routes anything here in Cloudflare. Deleting would surface the same 404 behavior from Cloudflare with less code.
- **Source:** c2

#### 12. `serialize_server_setup` marked `#[allow(dead_code)]`

- **Files:** `backend-rust/src/opaque.rs:40-43`
- **Category:** dead-code | **Type:** Local
- **Impact:** 1/5
- **Confidence:** 5/5
- **Contagion:** 1/5
- **Evidence:** Only `#[allow(dead_code)]` in the Rust codebase. Grep confirms zero callers. `generate_setup.rs` binary does its own inline implementation without importing this function. AGENTS.md forbids ignoring warnings instead of fixing root cause.
- **Recommendation:** Remove
- **Source:** c3

#### 13. Public OPAQUE wire DTOs in routes.rs lack doc comments

- **Files:** `backend-rust/src/routes.rs:10,17,23,30,36,43,50,58,65`
- **Category:** missing-docs | **Type:** Local
- **Impact:** 2/5
- **Confidence:** 3/5
- **Contagion:** 2/5
- **Evidence:** 9 `pub struct`s (RegisterStart/Finish, LoginStart/Finish, etc.) form the cross-language wire contract with iOS OpaqueAuthService. None have `///` docs describing base64 vs plain, expected lengths, or state-token semantics. Only inline `//` comment at `:83` hints at `client_identifier` being 64 hex chars.
- **Recommendation:** Document (short `///` lines per struct referencing ADR-0011, or field-level docs for anything ADR-0011 doesn't already specify)
- **What's unknown:** Whether ADR-0011 already specifies the wire format in enough detail that `/// See ADR-0011.` suffices, or whether per-field docs are needed.
- **Source:** b12

#### 14. `hex` crate declared in `Cargo.toml` but never imported

- **Files:** `backend-rust/Cargo.toml:21`
- **Category:** vestigial-dependency | **Type:** Local
- **Impact:** 1/5
- **Confidence:** 5/5
- **Contagion:** 1/5
- **Evidence:** Zero `use hex` / `hex::` in `backend-rust/`. Only string match is an inline comment. Base64 is used everywhere. Unused dep inflates WASM build time and audit surface for the auth Worker.
- **Recommendation:** Remove
- **Source:** m1

---

### Group 3: Views/UI (6 findings)

#### 15. Spurious `import UIKit` in CameraCaptureController.swift

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/Camera/CameraCaptureController.swift:3`
- **Category:** spurious-import | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 2/5
- **Evidence:** No `UI*` symbols in file body. Uses AVFoundation + Foundation + CoreGraphics (via AVFoundation).
- **Recommendation:** Remove
- **Source:** c4

#### 16. Spurious `import UIKit` in ThumbnailDisplayMode.swift

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/ThumbnailDisplayMode.swift:1`
- **Category:** spurious-import | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 2/5
- **Evidence:** Enum uses only String/Data/Bool. Foundation suffices.
- **Recommendation:** Remove
- **Source:** c5

#### 17. `SettingsViewPreviewHelpers.swift` is a separate file for a preview block

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Settings/SettingsViewPreviewHelpers.swift`
- **Category:** organization-shim | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 4/5 | **Contagion:** 3/5
- **Evidence:** Entire file in `#if DEBUG`, contains `#Preview` + four preview stubs. Carries a 0.0 coverage exception in `scripts/check-coverage.sh:104` just to satisfy the per-file threshold.
- **Recommendation:** Consolidate into `SettingsView.swift` under a single `#if DEBUG` block; remove coverage exception
- **Source:** c10

#### 18. Stale `TODO(#127)` referencing a CLOSED issue

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/ViewModels/Records/MedicalRecordListViewModel.swift:105`
- **Category:** todo-fixme | **Type:** Local
- **Impact:** 3/5 | **Confidence:** 5/5 | **Contagion:** 2/5
- **Evidence:** Comment reads `// TODO(#127): sort by clinical event date`. Issue #127 is CLOSED. Sort at line 108 still uses `record.createdAt`.
- **Recommendation:** Needs your call — either re-file as a new issue + update TODO, or delete the TODO if clinical-date sorting was abandoned
- **Source:** b5

#### 19. `DocumentBlobService` magic numbers undocumented

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Document/DocumentBlobService.swift:82,83`
- **Category:** hidden-default-magic | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 5/5 | **Contagion:** 3/5
- **Evidence:** `maxFileSizeBytes = 10 * 1_024 * 1_024`, `thumbnailDimension = 200`. No doc/ADR. 10 MB limit surfaces to users via `ModelError.documentTooLarge`.
- **Recommendation:** Document (rationale in `///` and/or link an ADR)
- **Source:** b10

#### 20. Camera focus-indicator timing uses bare nanosecond literal + inline durations

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Documents/Camera/CameraCaptureView.swift:240,242,243`
- **Category:** hidden-default-magic | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 5/5 | **Contagion:** 3/5
- **Evidence:** `Task.sleep(nanoseconds: 600_000_000)` (0.6s) alongside `easeOut(duration: 0.25)` and `easeIn(duration: 0.15)`. Three values, three forms.
- **Recommendation:** Inline — introduce named constants (`focusIndicatorVisibleDuration`, `focusFadeIn`, `focusFadeOut`). Switch to `Task.sleep(for: .milliseconds(600))` (iOS 16+).
- **Source:** b11

---

### Group 4: Models / Repos / Logging (5 findings, 1 rejected)

#### 21. REJECTED: TracingCategoryLogger pass-through wrapper is justified

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Logging/TracingCategoryLogger.swift:59-127`
- **Reason:** Since the wrapper conforms to `CategoryLoggerProtocol`, the 14 pass-throughs are *required* to satisfy the protocol; they allow 16 services to hold a single logger reference mixing tracing + regular log calls. Only finding here is that the design intent (migration path toward a `@Traced` macro, per existing doc comment at line 17-18) could be more prominent.
- **Impact:** 1/5 (as debt) → rejected
- **Recommendation:** No action — doc-only if desired
- **Source:** c1

#### 22. Duplicated private `trimmedNonEmpty` in PersonBackup and ProviderBackup

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Models/Backup/PersonBackup.swift:66-72`, `ios/FamilyMedicalApp/FamilyMedicalApp/Models/Backup/ProviderBackup.swift:86-92`
- **Category:** duplication | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 5/5 | **Contagion:** 3/5
- **Evidence:** Identical private funcs. New FHIR backup models will copy the pattern if left.
- **Recommendation:** Consolidate into a `String?` extension or shared helper
- **Source:** c6

#### 23. Casing inconsistency: `personID` vs `personId`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Repository/PersonRepository.swift:157,160,165`, `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Provider/ProviderRepository.swift:221,223`
- **Category:** naming-inconsistency | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 5/5 | **Contagion:** 4/5
- **Evidence:** `personId` in 76 files (dominant); `personID` in two private helpers only. `recordID`/`userID` show same drift. Swift API Design Guidelines prefer `Id`.
- **Recommendation:** Consolidate — rename to `personId`
- **Source:** c7

#### 24. Entity terminology drift: `familyMemberID` vs `personId`

- **Files:** `FamilyMemberKeyService.swift:32,40,80,98`, `PersonRepository.swift:160,165,222`, `ProviderRepository.swift:223`, `DocumentBlobService.swift:150,193`, `DocumentReferenceQueryService.swift:117`, `ImportService.swift:77`, `ExportService.swift:103`
- **Category:** naming-inconsistency | **Type:** Foundational
- **Impact:** 3/5 | **Confidence:** 3/5 | **Contagion:** 5/5
- **Evidence:** `FamilyMemberKeyService.storeFMK(familyMemberID:)` takes a `String` param named with the crypto-layer term; every caller passes `person.id.uuidString`. Keychain identifiers are `fmk.<id>`.
- **Recommendation:** Needs your call — either align on `personId` (rename the API) or document "familyMember" as a deliberate crypto abstraction distinct from `Person`
- **What's unknown:** Whether "family member" is intentional architecture (e.g., FMKs may later key non-Person entities).
- **Source:** c8

#### 25. `ensureFMK` in ProviderRepository flattens all errors to `keyNotAvailable`

- **Files:** `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Provider/ProviderRepository.swift:221-227`
- **Category:** hidden-default-implicit | **Type:** Local
- **Impact:** 2/5 | **Confidence:** 4/5 | **Contagion:** 2/5
- **Evidence:** `PersonRepository.ensureFMK` distinguishes `keyNotFound` (generate new) from other errors; `ProviderRepository.ensureFMK` catches all errors as `keyNotAvailable`. The comment "must already exist — providers are always under an existing person" encodes an invariant but the error message hides the true failure mode.
- **Recommendation:** Document (clarify the invariant) or propagate the underlying error type
- **Source:** New (Phase 3)

---

### Group 5: Docs / Meta (9 findings, 2 rejected)

#### 26. **`docs/adr/examples/key-hierarchy-poc.swift` uses PBKDF2 (100k iters) + CommonCrypto — contradicts ADR-0002**

- **Files:** `docs/adr/examples/key-hierarchy-poc.swift:1,16,24,29`
- **Category:** misleading-reference-example | **Type:** Foundational
- **Impact:** 4/5 — PBKDF2 at 100k iters is explicitly rejected by ADR-0002 in favor of Argon2id via Swift-Sodium. An orphan example in `docs/adr/examples/` promoting the wrong KDF is actively misleading.
- **Confidence:** 5/5 — not referenced by any ADR; three other POC files under `docs/research/` are the ones cited by ADRs 0002/0003.
- **Contagion:** 3/5 — copy-paste risk
- **Evidence:** Line 1: `import CommonCrypto`. Lines 18-29: `CCKeyDerivationPBKDF(...SHA256..., rounds: 100_000, ...)`. ADR-0002:81,83,95,115,133,137 mandates Argon2id + Swift-Sodium. AGENTS.md Quick Reference: "CryptoKit + Swift-Sodium only (NO custom crypto)".
- **Recommendation:** Remove the file
- **Source:** c9 (partial)

#### 27. REJECTED: `docs/research/poc-*.swift` files serve their cited purpose

- **Files:** `docs/research/poc-hybrid-family-keys.swift`, `docs/research/poc-public-key-sharing.swift`, `docs/research/poc-symmetric-key-wrapping.swift`
- **Reason:** Referenced from ADR-0002:462, ADR-0003:580-581, and `docs/research/README.md:26/32/38`. Algorithms align with ADR spec. Dependency-graph noise is a tooling artifact, not a codebase problem.
- **Recommendation:** No action — the POCs are intentional documentary references
- **Source:** c9 (partial)

#### 28. REJECTED: ADR-0009 references removed symbols (orphaned-docs false positive)

- **Reason:** ADRs are immutable historical records. `README.md:61` and the ADR's own banner already mark it "Superseded (2026-01-02)". No action needed beyond what was already done in the accompanying cleanup PR (pruning the broken "See: schema-evolution-design.md" link).
- **Source:** b4

#### 29. REJECTED: UITests `import XCTest` (naming-inconsistency false positive)

- **Reason:** Already documented: `docs/testing-patterns.md:3` distinguishes Swift Testing (unit) from XCTest (UI). `scripts/check-no-xctest-in-unit-tests.sh` + `.pre-commit-config.yaml` enforce the split with a documented exemption for UI tests. No action needed.
- **Source:** c12

#### 30. Root `.gitignore`: Python-only rules for a non-Python repo

- **Files:** `.gitignore:42-46,62-64`
- **Category:** orphaned-config | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 1/5
- **Evidence:** `.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.coverage`, `htmlcov/`. Zero `*.py` files in repo.
- **Recommendation:** Remove
- **Source:** m2

#### 31. `ios/.gitignore`: Unused Carthage / Accio / fastlane / iOSInjectionProject rules

- **Files:** `ios/.gitignore:67,70-71,80-83,95`
- **Category:** orphaned-config | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 1/5
- **Evidence:** AGENTS.md specifies SPM only. Looks seeded from the GitHub Swift.gitignore template.
- **Recommendation:** Remove
- **Source:** m3

#### 32. Both `.gitignore`s: Xcode 3/4/8-compatibility patterns (self-labelled)

- **Files:** `.gitignore:5,6,9,11-17`, `ios/.gitignore:9-22`
- **Category:** orphaned-config | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 1/5
- **Evidence:** Inline comments in `ios/.gitignore` already flag them: line 8 "Compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)"; line 12 "Compatibility with Xcode 3 and earlier". Project requires Xcode 26.2+.
- **Recommendation:** Remove
- **Source:** m4

#### 33. Root and `ios/.gitignore` substantially overlap

- **Files:** `.gitignore:3-25`, `ios/.gitignore:1,49` and much more
- **Category:** orphaned-config | **Type:** Local
- **Impact:** 1/5 | **Confidence:** 5/5 | **Contagion:** 1/5
- **Evidence:** Both files carry `xcuserdata/`, `DerivedData/`, `build/`, `*.dSYM`, `*.hmap`, `*.ipa`, `timeline.xctimeline`, `playground.xcworkspace`, `.build/`. Root would cover `ios/` already.
- **Recommendation:** Consolidate — keep root; delete `ios/.gitignore` after merging unique patterns (e.g., `*/coverage.json`) upward
- **Source:** New (Phase 3)

#### 34. Contradictory coverage threshold between AGENTS.md and ADR-0006 summary

- **Files:** `AGENTS.md`, `docs/adr/README.md:71`
- **Category:** stale-docs | **Type:** Data
- **Impact:** 2/5 | **Confidence:** 4/5 | **Contagion:** 2/5
- **Evidence:** AGENTS.md: "Overall project coverage: 85% minimum (temporarily reduced from 90% for OPAQUE auth, see Issue #78)". README.md:71: "90% overall project coverage minimum, 85% per-file minimum". Reader gets conflicting numbers.
- **Recommendation:** Document — update ADR-0006 README summary to reflect the temporary 85% with Issue #78 reference, or set a restoration date
- **What's unknown:** Whether the ADR-0006 body is also out of date. Not read in this pass.
- **Source:** New (Phase 3)

---

## Bugs Found

None. Several findings point at *foundational* concerns (implicit behavior, undocumented defaults, shims) but nothing in this review qualifies as a functional bug — the code works; it just shouldn't exist as-is.

## Rejected Candidates

- **c1** TracingCategoryLogger pass-throughs — justified by protocol design (finding #21)
- **b4** ADR-0009 orphan refs — preserved per ADR convention (finding #28)
- **c12** UITest XCTest split — already documented (finding #29)
- **c9 (partial)** docs/research/poc-*.swift — intentional ADR references (finding #27)
