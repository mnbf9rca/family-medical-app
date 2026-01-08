# ADR-0010: Deterministic Testing Architecture

## Status

**Accepted** (2026-01-08)

## Context

Tests using `Date()`, `UUID()`, or `Task.sleep` are non-deterministic—they pass locally but fail in CI due to timing differences. This causes flaky tests and unreliable assertions.

## Decision

Adopt `swift-dependencies` for system dependencies only:

- `@Dependency(\.date)` - Controllable Date
- `@Dependency(\.uuid)` - Controllable UUID
- `@Dependency(\.continuousClock)` - Controllable timing

This coexists with ADR-0008's optional parameter pattern:

- **swift-dependencies**: System dependencies (Date, UUID, Clock)
- **ADR-0008 optional parameters**: Application services (repositories, crypto)

**Security constraint**: Crypto services (EncryptionService, FMKService, PrimaryKeyProvider) must NOT use swift-dependencies. Keys must never be stored in global dependency state.

## Consequences

**Positive**: Eliminates date/time test flakiness; exact equality assertions replace tolerance windows.

**Negative**: Additional package dependency; two DI patterns in codebase.

## References

- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies)
- [Implementation patterns](../testing-patterns.md#deterministic-testing-with-swift-dependencies)
- GitHub Issue #81
