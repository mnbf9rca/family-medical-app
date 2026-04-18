# ADR-0010: Deterministic Testing Architecture

## Status

**Superseded** (2026-04-18)

> **Tombstone (2026-04-18):** The `swift-dependencies` library this ADR adopted was removed in PR 6 of the day-1 review. A codebase audit found zero adopters — no `import Dependencies`, no `@Dependency` property wrappers, and no `withDependencies` calls anywhere in `ios/`. The package was wired into the Xcode project but never used. Per AGENTS.md's KISS/YAGNI principle, we removed the dependency rather than leave half-finished infrastructure.
>
> The underlying concern — non-determinism from `Date()`, `UUID()`, and `Task.sleep` in tests — remains valid. Future callers needing deterministic tests should use manual dependency injection per [ADR-0008](adr-0008-swift-6-concurrency.md)'s optional-parameter pattern, injecting `any Clock` or `() -> Date` directly through initializers.

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
- GitHub Issue #81
