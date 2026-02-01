# Agent Guidelines

## ⚠️ CRITICAL RULES

**Subagents frequently violate these rules. Read carefully.**

### Environment & Execution

- ⚠️ **NEVER** start processes detached
  - No `nohup`, no `&`, no daemon mode
  - If needed, use background bash processes
  - Use foreground processes in background shells for proper log access
- ⚠️ Use `ast-grep` for code modifications
  - **NEVER** use `sed` or `awk` - they corrupt complex files

### Code Quality and Testing

- ⚠️ **ALWAYS** run `pre-commit run --all-files` before committing
- ⚠️ **NEVER** use ignores to suppress linting errors or warnings
  - Refactor the code instead, especially for complexity warnings
  - Use pure functions to reduce complexity
- ⚠️ **NEVER** skip or override pre-commit hooks
  - The hooks are there for a reason - fix the issues instead
- ⚠️ **ALWAYS** achieve required code coverage thresholds, validated through testing:
  - **Overall project coverage: 87% minimum** (temporarily reduced from 90% for OPAQUE auth, see Issue #78) and **individual file coverage: 85% minimum** (with exceptions for specific files, see `scripts/check-coverage.sh` - only add exceptions with explicit user consent)
  - Coverage applies to existing, new, **and changed** code
  - Use `{projectRoot}/scripts/run-tests.sh` to run iOS tests - this is the same script used in CI. Note that it can take up to 15 minutes for the full (UI) test suite to run. Do **NOT** tail results - the script already uses xcpretty, and tail will prevent you seeing warnings.
  - **After** running tests, use `{projectRoot}/scripts/check-coverage.sh` to validate iOS coverage - this is the same script used in CI
  - Use `--detailed` flag with check-coverage.sh to see function-level coverage details for files below 100%
  - **Using other methods will fail CI** meaning the PR cannot be merged
  - Create tests up front or as you go to ensure you hit coverage

## Principles

- This is a hobby project - prefer KISS, DRY, YAGNI over enterprise patterns
- **Before starting work, always read:**
  - [ADRs](docs/adr/README.md) - Architecture decisions and rationale
  - [Coding Practices](docs/coding-practices.md) - Standards and patterns
  - [Testing Patterns](docs/testing-patterns.md) - UI testing guidance
- Consider whether your changes warrant updating the ADRs; include this as a task if needed

## Testing Requirements

For security-critical code (auth, encryption, key derivation, sharing):

- Write unit tests
- Test failure cases (wrong password, corrupted data, missing keys)
- Test key rotation and access revocation

## Git Workflow

### Branch Management

- If on `main`: pull latest changes and create a new branch
- If NOT on `main`: ask user whether to "work on current branch" or "checkout main, pull latest, and create new branch" BEFORE beginning work

### Commits

- Never commit or push until the user gives you an explicit instruction
- **Never** amend commits
- Do not create new GitHub labels

### Pull Requests

- Warn the user if the resulting PR is likely to be too large to review easily
- Suggest breaking it into smaller PRs, although note that the build and test on a PR typically takes around 6-8 minutes.

### Issue Tracking

- If working on an issue, update the GitHub issue as you progress, not at the end
- If your plan changes, update the issue with the new plan as you go
- Prefer editing one comment over posting several comments tracking progress

### GitHub

- Use `gh` command for all GitHub-related tasks
- Working with issues, pull requests, checks, releases, etc.

## Tech Stack

### iOS

The versions below are available, despite this being beyond your knowledge cutoff:

- **Xcode**: 26.2+ (December 2025) -> use `xcpretty` to manage output, not `grep` or `tail`.
- **available simulators**: iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max and others, but *not* iPhone 16
- **Swift**: 6.2.3+ (ships with Xcode 26.2)
- **iOS Deployment Target**: 17.6+ (required for @Observable macro, covers 84.7% of devices)
- **iOS SDK**: 26.2+ (build with latest SDK, but deploy to older iOS versions)
- **UI**: SwiftUI only
- **Crypto**: CryptoKit (Apple's framework) + Swift-Sodium (libsodium for Argon2id) + opaque-ke (Rust) → UniFFI → Swift XCFramework
- **Auth**: LocalAuthentication framework
- **Storage**: Core Data with field-level encryption (CryptoKit)
- **Networking**: URLSession with certificate pinning

### Cryptography & Security

**Read the ADRs for complete specifications:**

- [ADR-0002: Key Hierarchy](docs/adr/adr-0002-key-hierarchy.md) - Crypto algorithms, key derivation, storage
- [ADR-0003: Multi-User Sharing Model](docs/adr/adr-0003-multi-user-sharing-model.md) - Sharing patterns, access control
- [ADR-0004: Sync Encryption](docs/adr/adr-0004-sync-encryption.md) - Encryption boundaries, metadata handling
- [ADR-0005: Access Revocation](docs/adr/adr-0005-access-revocation.md) - Key rotation, re-encryption
- Any other relevant ADR.

**Quick reference:**

- Use CryptoKit + Swift-Sodium only (NO custom crypto)
  - Swift-Sodium is an audited wrapper around libsodium (NOT custom crypto)
  - Required for Argon2id (password hashing competition winner, better GPU resistance)
- Primary Key and Private Key NEVER leave device
- Always provide biometric auth fallback

## Communication Style

**Be direct. No fluff.**

### Don't

- Suggest what to do while waiting for downloads/builds
- Say "Let me know when..." (user will tell you)
- Offer patronizing suggestions ("take a break", "review the docs")
- Add encouragement or motivational content
- State the obvious ("this is a big download")
- Repeat information already in documentation

### Do

- Give only necessary technical information
- State what's required, then stop
- Answer questions directly
- Provide context only when it prevents mistakes

---

See README.md for architecture and threat model.
