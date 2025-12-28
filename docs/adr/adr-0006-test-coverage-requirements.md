# Test Coverage Requirements and Dual Threshold System

## Status

**Status**: accepted

**Date**: 2025-12-28

## Context

As a medical records application handling sensitive health data, code quality and reliability are critical. Bugs in security-critical components (authentication, encryption, key derivation) could lead to data breaches or loss. We need a systematic approach to ensure all code paths are tested, especially for:

- Authentication and authorization logic
- Cryptographic operations (encryption, key derivation, key wrapping)
- Data access and sharing controls
- Security-sensitive state transitions (app locking, scene phase handling)

However, some code paths are inherently difficult or impossible to test without mocking framework internals:

- CryptoKit defensive error catches that only trigger on framework bugs
- SwiftUI compiler-generated closures for UI actions
- Implicit closures from default arguments

We need a coverage policy that enforces high quality while allowing practical exceptions.

## Decision

### Dual Threshold System

1. **Overall Project Coverage: 90% minimum**
   - Measures aggregate coverage across all application code
   - Ensures the codebase as a whole maintains high quality
   - Prevents coverage "holes" from accumulating

2. **Individual File Coverage: 85% minimum**
   - Each file must meet 85% coverage independently
   - Allows flexibility for files with unreachable defensive code
   - Prevents any single file from dragging down overall coverage

3. **Per-File Exceptions**
   - Documented in `scripts/check-coverage.sh`
   - Example: `EncryptionService.swift` at 80% (defensive CryptoKit error catches unreachable without mocking framework internals)
   - Exceptions require justification in code comments

### Enforcement

- CI fails if EITHER threshold is not met (both conditions required)
- Coverage checked via `scripts/check-coverage.sh` after `scripts/run-tests.sh`
- Detailed mode (`--detailed` flag) shows function-level coverage for debugging

### Testing Requirements for Security-Critical Code

All security-critical components require:

- Unit tests for happy paths
- Failure case tests (wrong password, corrupted data, missing keys)
- Edge case coverage (key rotation, access revocation, concurrent access)

## Consequences

### Positive

- **Higher code quality**: 90% overall threshold catches most regression risks
- **Flexibility**: 85% per-file allows practical exceptions for defensive code
- **Transparency**: `--detailed` flag helps developers identify uncovered code paths
- **Consistency**: Same scripts used locally and in CI
- **Security focus**: Explicit requirements for security-critical code testing

### Negative

- **Additional test maintenance**: High coverage requires ongoing test updates as code evolves
- **Slower PR reviews**: Coverage checks add ~6-8 minutes to CI pipeline
- **Learning curve**: Developers must understand dual threshold system and exceptions

### Neutral

- **Exception management**: Per-file exceptions documented in script (visible but requires discipline to maintain)
- **95.24% achievable**: Most files already exceed 90%, suggesting threshold is realistic
