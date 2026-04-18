# Day 1 Review Cleanup — Tracker

Companion to:

- `2026-04-18-detailed-report.md` — full findings + evidence
- `2026-04-18-ready-to-fix.md` — per-finding fix spec

## Workflow per PR

1. New Claude session (clean context)
2. Read this file + the ready-to-fix spec for the findings in scope
3. Dispatch a single Opus subagent to implement the PR
4. Review returned diff + run build/tests/coverage/pre-commit
5. Commit on the PR branch (no push during iteration)
6. Once green and reviewed: push + open PR
7. User merges on GitHub
8. Local `git checkout main && git pull`
9. Mark this PR **merged** in the table below, update the next row to **in-progress**
10. New session for next PR

## PR queue

| # | Branch | Findings | Status | Notes |
|---|---|---|---|---|
| 1 | `chore/phase-1-cleanup` | **#1, 2, 3, 9** + batch-2 **#7, 15, 16, 18, 20, 25-30**; **#17 rejected** | merged (PR #167) | Squash-merged as `9bd8862` on 2026-04-18. Finding #17 rejected on implementation — `SettingsViewPreviewHelpers.swift` is load-bearing: merging into `SettingsView.swift` pushes it past SwiftLint `file_length` warning which `--strict` treats as error. Original two-file split is the correct design. |
| 2 | `docs/auth-rationale` | doc-only: **#4, 5, 6, 8, 10, 13, 19, 24** | pending | Pure `///` additions across auth, backend wire DTOs, repositories. Can't regress anything. |
| 3 | `chore/delete-placeholder-backend` | structural deletes: **#11, 12, 14** | pending | Removes `backend/` directory entirely + `serialize_server_setup` + `hex` crate. Check Cloudflare routing before deploy. |
| 4 | `refactor/id-naming` | wide rename: **#21, 22, 23** | pending | `trimmedNonEmpty` consolidation; `personID→personId`, `familyMemberID→personId`. Repo-wide — isolate for diff clarity. |

## Finding index (for subagent briefings)

All details are in `2026-04-18-ready-to-fix.md`. The finding number there is the same as here.

### PR 1 remaining findings

- **#7** — Consolidate DEBUG + Release OPAQUE test-bypass on `isUITesting` (`OpaqueAuthService.swift:394-405`)
- **#15** — Remove spurious `import UIKit` in `CameraCaptureController.swift:3`
- **#16** — Remove spurious `import UIKit` in `ThumbnailDisplayMode.swift:1`
- **#17** — ~~Merge `SettingsViewPreviewHelpers.swift` into `SettingsView.swift`, drop coverage exception~~ **Rejected:** merging pushes `SettingsView.swift` past SwiftLint's 500-line warning, and pre-commit runs `swiftlint --strict` which treats warnings as errors. The separation is load-bearing, not gratuitous.
- **#18** — Delete stale `TODO(#127)` in `MedicalRecordListViewModel.swift:105`
- **#20** — Name CameraCaptureView focus-indicator timing constants (`CameraCaptureView.swift:240,242,243,252`)
- **#25** — Delete `docs/adr/examples/key-hierarchy-poc.swift` (contradicts ADR-0002)
- **#26** — Remove Python-only rules from root `.gitignore:42-46,62-64`
- **#27** — Remove Carthage/Accio/fastlane/iOSInjectionProject rules from `ios/.gitignore:67,70-71,80-83,95`
- **#28** — Remove Xcode 3/4/8 compatibility patterns from both `.gitignore`s
- **#29** — Consolidate: delete `ios/.gitignore`, fold unique rules into root
- **#30** — Update `docs/adr/README.md:71` ADR-0006 summary to match current 80% threshold (+ Issue #78 and Issue #160 references)

### PR 2 findings

- **#4** — Doc `defaultBaseURL` in `OpaqueAuthService.swift:25-27`
- **#5** — Doc `defaultTimeout` in `LockStateService.swift:9,37` (security rationale)
- **#6** — Doc `rateLimitThresholds` in `AuthenticationService.swift:90-96` (client vs server layer distinction)
- **#8** — Rewrite `KeyDerivationService` protocol doc for backup-only usage
- **#10** — Update `derivePrimaryKey(from:salt:)` parameter doc
- **#13** — Doc 9 `pub struct` wire DTOs in `backend-rust/src/routes.rs:10,17,23,30,36,43,50,58,65`
- **#19** — Doc `maxFileSizeBytes` + `thumbnailDimension` in `DocumentBlobService.swift:82,83`
- **#24** — Doc `ensureFMK` invariant + log underlying error in `ProviderRepository.swift:221-227`

### PR 3 findings

- **#11** — Delete entire `backend/` directory (TS placeholder Worker)
- **#12** — Delete `serialize_server_setup` + its `#[allow(dead_code)]` in `backend-rust/src/opaque.rs:40-43`
- **#14** — Remove `hex = "0.4"` from `backend-rust/Cargo.toml:21`

### PR 4 findings

- **#21** — Consolidate duplicate `trimmedNonEmpty` into shared `String?` extension (PersonBackup + ProviderBackup)
- **#22** — Rename `personID/recordID/userID` → `personId/recordId/userId` repo-wide
- **#23** — Rename `familyMemberID` → `personId` across FMK APIs and all call sites

## Deferred items

Phase 3 surfaced four rejected candidates (TracingCategoryLogger pass-throughs, docs/research POCs, ADR-0009 orphan refs, UITest XCTest split) — no action, see detailed report §Rejected Candidates.

**Rejected on implementation (discovered during PR #1 execution):**

- **#17** — Preview-helpers file is load-bearing for SwiftLint `file_length`; see tracker row for PR #1.

## Follow-ups discovered during execution (filed as separate issues)

- **Smoke-test cold-start flake (PR #2 CI):** `scripts/run-tests.sh` is fine; the issue is in `backend-rust/tests/smoke_test.sh` (preview-deployment smoke test). `OPTIONS /auth/opaque/register/start` returned 500 transiently on PR #169 CI; live curl returned 200 immediately after. Suggested mitigation: add one retry with ~2s backoff on 5xx to absorb cold-start flakiness. Root-cause investigation (whether the preview Worker has a first-request panic-hook race during module init) is separate.

## Decisions taken

- **Cloudflare `recordwell-api` Worker left in place (PR #3):** After deleting `backend/`, the `recordwell-api` Worker on Cloudflare and its `api.recordwell.app/*` Custom Hostname route are now orphaned from the repo. Decided to leave them running — the handler is a pure 410/404 responder, iOS traffic goes through the Rust Worker's explicit `/auth/opaque/*` and `/health/*` routes, and the operational debt is lower-cost than the dashboard cleanup. No follow-up issue.

## AGENTS.md rules subagents MUST follow

Copy into each subagent brief:

- Day-1 correctness — delete old code when replacing, no shims, no compat scaffolding
- Never `sed`/`awk` for Swift — use `ast-grep` or `Edit`
- Never skip pre-commit hooks, never `--no-verify`
- Never suppress lint warnings; refactor instead
- Use `TracingCategoryLogger` for service entry/exit logging
- ≥80% overall, ≥85% per-file coverage
- Unit tests use Swift Testing (`import Testing`); UI tests use XCTest
- **Verification order (fail-fast):** `mcp__xcode__BuildProject` → `pre-commit run --all-files` → `scripts/run-tests.sh` → `scripts/check-coverage.sh`. Lint runs in seconds; tests take 8-15 min. Never run tests before pre-commit — saves up to 15 min per failed run.
- Use `mcp__xcode__BuildProject` with `tabIdentifier: windowtab1` for fast build check
