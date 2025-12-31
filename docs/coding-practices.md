# Coding Practices

## Overview

This document contains coding standards and best practices for the Family Medical App. These practices help maintain code quality, security, and maintainability.

**Before starting work, always read:**

- [ADRs](adr/README.md) - Architecture decisions and rationale
- This document - Coding standards and patterns
- [SwiftUI XCUITest Gotchas](swiftui-xcuitest-gotchas.md) - UI testing workarounds

---

## Error Handling

### User-Facing Error Messages

**❌ DON'T** expose `error.localizedDescription` directly to users:

```swift
// BAD - exposes internal details
errorMessage = "Failed to load: \(error.localizedDescription)"
```

**✅ DO** use generic, user-friendly messages:

```swift
// GOOD - user-friendly and secure
errorMessage = "Unable to load your data. Please try again."
print("DEBUG: Load failed with error: \(error.localizedDescription)")
```

**Rationale:**

- `error.localizedDescription` can leak sensitive details (file paths, database schemas, crypto internals)
- Medical app users need clear guidance, not technical jargon
- Debugging information belongs in logs, not the UI

### Error Logging

**✅ DO** use `LoggingService` for privacy-aware error logging:

```swift
// In ViewModels, add a logger dependency
private let logger = LoggingService.shared.logger(category: .ui)

catch {
    // Show generic message to user
    errorMessage = "Unable to save this member. Please try again."

    // Log detailed error (error details are private, context is public)
    logger.logError(error, context: "HomeViewModel.createPerson")
}
```

**❌ DON'T** use `print()` - SwiftLint will reject it:

```swift
// BAD - violates no_print_in_production rule
print("ERROR: \(error)")
```

**Log Categories:**

- `.auth` - Authentication and user account management
- `.crypto` - Cryptographic operations and key management
- `.storage` - Local storage and data persistence
- `.sync` - Cross-device synchronization
- `.ui` - User interface and view operations

### Known/Expected Errors

For **validation errors** or **expected conditions**, provide specific guidance:

```swift
// Validation errors should be specific
if name.isEmpty {
    validationError = "Please enter a name"
}

// Map known errors to helpful messages
switch error {
case DataError.duplicateName:
    errorMessage = "A member with this name already exists."
case DataError.invalidDate:
    errorMessage = "Please enter a valid date of birth."
default:
    errorMessage = "Unable to save this member. Please try again."
    print("ERROR: Unexpected error: \(error)")
}
```

---

## SwiftUI Best Practices

### State Management

- Use `@StateObject` for ViewModels owned by a View
- Use `@ObservedObject` for ViewModels passed from parent
- Use `@State` for view-local UI state only

### Concurrency

See [ADR-0008: Swift 6 Concurrency Patterns](adr/adr-0008-swift-6-concurrency.md) for detailed guidance.

**Quick reference:**

- Mark ViewModels with `@MainActor` for UI updates
- Use `@unchecked Sendable` for manually thread-safe services (NSLock-based)
- Use `nonisolated(unsafe)` sparingly for protocol conformance

---

## Testing Practices

### Coverage Requirements

See [ADR-0006: Test Coverage Requirements](adr/adr-0006-test-coverage-requirements.md).

**Summary:**

- Overall: 90% minimum
- Per-file: 85% minimum (with documented exceptions)
- Security-critical code: Unit tests + failure cases mandatory

### UI Testing

See [SwiftUI XCUITest Gotchas](swiftui-xcuitest-gotchas.md) for common issues.

**Key practices:**

- Use `waitForExistence(timeout:)` instead of `sleep()`
- Use accessibility identifiers for stable element selection
- Use helper methods for reusable patterns

---

## Security Practices

### Cryptography

**Never implement custom crypto.** Use:

- **CryptoKit** (Apple's framework) for standard operations
- **Swift-Sodium** (audited libsodium wrapper) for Argon2id only

See [ADR-0002: Key Hierarchy](adr/adr-0002-key-hierarchy.md) for specifications.

### Sensitive Data

- Primary Key and Private Key NEVER leave device
- Always provide biometric auth fallback
- Use SecureField for password input (except in UI testing mode - see [SwiftUI XCUITest Gotchas](swiftui-xcuitest-gotchas.md))

---

## Naming Conventions

- ViewModels: `<Feature>ViewModel` (e.g., `HomeViewModel`)
- Services: `<Purpose>Service` (e.g., `KeychainService`)
- Protocols: `<Capability>` (e.g., `PersonRepository`)

---

## Pre-Commit Checklist

Before committing:

1. ✅ Run `pre-commit run --all-files` (NEVER skip hooks)
2. ✅ Ensure tests pass: `./scripts/run-tests.sh`
3. ✅ Verify coverage: `./scripts/check-coverage.sh`
4. ✅ Fix linting/formatting errors (don't ignore them)
5. ✅ Review your changes for exposed sensitive data

---

## References

- [ADRs](adr/README.md) - All architecture decisions
- [AGENTS.md](../AGENTS.md) - Agent-specific guidelines
- [SwiftUI XCUITest Gotchas](swiftui-xcuitest-gotchas.md) - UI testing guidance
- [README.md](../README.md) - Project architecture and threat model
