# Coding Practices

## Overview

This document contains coding standards and best practices for the Family Medical App. These practices help maintain code quality, security, and maintainability.

**Before starting work, always read:**

- [ADRs](adr/README.md) - Architecture decisions and rationale
- This document - Coding standards and patterns
- [Testing Patterns](testing-patterns.md) - UI testing patterns and solutions

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

### Service Layer Logging

**✅ DO** inject loggers via initializer with default:

```swift
final class AttachmentService: AttachmentServiceProtocol, @unchecked Sendable {
    private let logger: CategoryLoggerProtocol

    init(
        // ... other dependencies ...
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    func addAttachment(_ input: AddAttachmentInput) async throws -> Attachment {
        // Log operations at debug level (UUIDs, file names, MIME types are safe)
        logger.debug("Adding attachment: \(input.fileName) (\(input.mimeType))")

        // ... implementation ...

        // Log errors with context
        logger.logError(error, context: "AttachmentService.addAttachment")
    }
}
```

**Log Level Guidelines:**

- `debug` - Routine operations, state changes (IDs, counts, file names)
- `info` - Significant events (user actions, sync completed)
- `notice` - Notable conditions that aren't errors (cache miss, retry)
- `error` - Recoverable failures (network timeout, validation failed)
- `fault` - Critical failures that indicate bugs (invariant violated)

**Privacy-Safe to Log:**

- UUIDs (person, record, attachment IDs)
- File names and MIME types
- Counts and timestamps
- Operation names and states

**Privacy-Sensitive (use `.private` or redact):**

- File content or encrypted data
- Encryption keys or HMACs
- Error messages that may contain paths/data
- Any medical information

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
    logger.logError(error, context: "ViewModel.saveOperation")
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

See [Testing Patterns](testing-patterns.md) for common issues and solutions.

**Key practices:**

- Use `waitForExistence(timeout:)` instead of `sleep()`
- Use accessibility identifiers for stable element selection
- Use helper methods for reusable patterns

**UI Test Infrastructure (FamilyMedicalAppUITests/):**

UI tests provide coverage for SwiftUI Views that cannot be unit tested (view body closures don't execute in ViewInspector). Use these patterns:

```swift
// Setup: Use launchForUITesting + createAccount (avoids manual setup/teardown)
app = XCUIApplication()
app.launchForUITesting(resetState: true)  // Clears keychain + Core Data
app.createAccount()                        // Creates user, navigates to HomeView

// Navigation helpers on XCUIApplication (see UITestHelpers.swift)
app.addPerson(name: "Test User")
app.verifyPersonExists(name: "Test User")
app.unlockApp(password: "...")
```

**Test File Organization:**

- `UITestHelpers.swift` - Shared helpers on `XCUIApplication` extension
- `*FlowUITests.swift` - Tests for specific feature flows (e.g., `MedicalRecordFlowUITests`)
- Use single consolidated test methods for CRUD workflows (XCTest doesn't guarantee ordering)

**When to Use UI Tests vs Unit Tests:**

| Component Type | Test Approach |
|----------------|---------------|
| ViewModel logic | Unit tests (Swift Testing) with mocks |
| SwiftUI View rendering | UI tests (XCTest) - body closures don't execute in unit tests |
| UIViewControllerRepresentable | UI tests - `makeUIViewController` needs SwiftUI context |
| Service layer | Unit tests with mocks |
| Repository layer | Unit tests with mock Core Data stack |

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
- Use SecureField for password input (except in UI testing mode - see [Testing Patterns](testing-patterns.md))

---

## Backup File Schema

The backup file format is defined by `docs/schemas/backup-v1.json` (JSON Schema Draft 2020-12). See [ADR-0012: JSON Schema Validation](adr/adr-0012-json-schema-validation.md) for details.

### Schema-Model Consistency

Consistency between the JSON Schema and Swift models is ensured through:

1. **Runtime validation** - `BackupSchemaValidator` validates all imported backup files against the schema
2. **Unit tests** - Tests serialize Swift models and validate them against the schema
3. **Pre-commit hook** - Validates the schema file is well-formed JSON Schema

### Workflow for Schema Changes

1. Edit `docs/schemas/backup-v1.json`
2. Update the corresponding Swift models in `Models/Backup/`
3. Run tests to verify schema-model consistency
4. Commit schema and model changes together

### DoS Protection

The validator enforces limits to prevent denial-of-service attacks:

- **Max nesting depth**: 20 levels (default)
- **Max array size**: 100,000 items (default)

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
