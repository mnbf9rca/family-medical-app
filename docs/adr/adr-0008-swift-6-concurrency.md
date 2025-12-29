# Swift 6 Concurrency Patterns

## Status

**Status**: Accepted (2025-12-29)

## Context

Swift 6 introduced strict concurrency checking to eliminate data races at compile time. The migration requires specific patterns that may appear counter-intuitive but are necessary for actor isolation correctness.

Key constraints:

- Default parameter expressions evaluate in the **caller's isolation domain**, not the function's
- Protocol methods without `@MainActor` cannot access MainActor-isolated properties in conforming types
- `@unchecked Sendable` is required when manual thread safety cannot be expressed to the compiler

## Decision

### Pattern 1: Optional Parameters for @MainActor Types

**Problem**: Cannot use `@MainActor` types as default parameters in `@MainActor` initializers.

```swift
// ❌ INCORRECT - Evaluates BiometricService() in caller's context
@MainActor
init(biometricService: BiometricServiceProtocol = BiometricService()) {
    self.biometricService = biometricService
}

// ✅ CORRECT - Evaluates BiometricService() inside @MainActor init
@MainActor
init(biometricService: BiometricServiceProtocol? = nil) {
    self.biometricService = biometricService ?? BiometricService()
}
```

**Rationale**: Default parameters are evaluated at the call site. If `BiometricService.init` is `@MainActor` but the caller isn't, this violates Swift 6 concurrency. The nil-coalescing pattern moves instantiation inside the `@MainActor init` body.

**Files**: `AuthenticationViewModel.swift`, `AuthenticationService.swift`

### Pattern 2: @unchecked Sendable for Manual Thread Safety

**Problem**: Services using NSLock for thread safety cannot prove Sendable to the compiler.

```swift
// ✅ CORRECT - NSLock provides thread safety
final class LoggingService: LoggingServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var loggers: [LogCategory: CategoryLogger] = [:]
    // All access to loggers protected by lock
}
```

**Rationale**: `@unchecked Sendable` is the standard pattern for types with manual synchronization (NSLock, DispatchQueue, os_unfair_lock). Converting to actors would require major architectural changes.

**Files**: `LoggingService.swift`, `EncryptionService.swift`, `KeyDerivationService.swift`, `KeychainService.swift`

### Pattern 3: @unchecked Sendable for Test Mocks

**Problem**: Test mocks cannot use `@MainActor` when their protocols aren't actor-isolated.

```swift
// ❌ INCORRECT - Breaks protocol conformance
@MainActor
final class MockCategoryLogger: CategoryLoggerProtocol { }

// ✅ CORRECT - Safe for MainActor-only test usage
/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
final class MockCategoryLogger: CategoryLoggerProtocol, @unchecked Sendable {
    private(set) var capturedEntries: [CapturedLogEntry] = []
}
```

**Rationale**: Marking mocks as `@MainActor` makes them non-conforming to non-isolated protocols. Test mocks are confined to MainActor test execution, making unsynchronized access safe.

**Files**: `MockLoggingService.swift`, `MockServices.swift`, `AuthenticationServiceTests.swift`

### Pattern 4: nonisolated(unsafe) for Protocol Constraints

**Problem**: Protocol methods without `@MainActor` cannot access MainActor properties.

```swift
@MainActor
final class MockBiometricService: BiometricServiceProtocol {
    // ✅ CORRECT - Protocol's authenticate() isn't @MainActor
    nonisolated(unsafe) var shouldFailAuthentication: Bool

    func authenticate(reason: String) async throws {
        // Can access shouldFailAuthentication from non-MainActor method
        if shouldFailAuthentication { throw error }
    }
}
```

**Rationale**: When a protocol method isn't actor-isolated but needs to access configuration state, `nonisolated(unsafe)` allows access. Safe for test mocks with immutable-after-init flags.

**Files**: `MockServices.swift`

## Consequences

### Positive

- Eliminates data races at compile time
- Makes actor isolation explicit and verifiable
- Documents thread safety assumptions with annotations

### Negative

- Optional parameter pattern appears to violate dependency injection best practices
- `@unchecked Sendable` requires careful review - cannot be verified by the compiler
- More verbose than Swift 5 code
- AI code reviewers may incorrectly flag these patterns as issues

## References

- Swift 6 Concurrency: <https://github.com/apple/swift-evolution/blob/main/proposals/0414-region-based-isolation.md>
- Actor Isolation: <https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md>
- PR #61: Swift 6 Migration
