import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("LaunchOrphanCleanupCoordinator Tests")
struct LaunchOrphanCleanupCoordinatorTests {
    // MARK: - Fixture

    private struct Fixture {
        let coordinator: LaunchOrphanCleanupCoordinator
        let cleanupService: MockOrphanBlobCleanupService
        let personRepository: MockPersonRepository
        let primaryKeyProvider: MockPrimaryKeyProvider
    }

    private static func makeFixture(primaryKey: SymmetricKey? = nil) -> Fixture {
        let cleanupService = MockOrphanBlobCleanupService()
        let personRepository = MockPersonRepository()
        let key = primaryKey ?? SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: key)
        let coordinator = LaunchOrphanCleanupCoordinator(
            cleanupService: cleanupService,
            personRepository: personRepository,
            primaryKeyProvider: primaryKeyProvider
        )
        return Fixture(
            coordinator: coordinator,
            cleanupService: cleanupService,
            personRepository: personRepository,
            primaryKeyProvider: primaryKeyProvider
        )
    }

    // MARK: - Plan's 3 Core Tests

    @Test("runCleanup calls cleanOrphans for each accessible person")
    func runCleanup_perPerson() async throws {
        let fixture = Self.makeFixture()
        // MockPersonRepository.fetchAll returns persons sorted alphabetically by name
        let alice = try Person(name: "Alice")
        let bob = try Person(name: "Bob")
        fixture.personRepository.addPerson(alice)
        fixture.personRepository.addPerson(bob)

        await fixture.coordinator.runCleanup()

        #expect(fixture.cleanupService.cleanOrphansCalls.count == 2)
        // Alphabetical order: Alice then Bob
        #expect(fixture.cleanupService.cleanOrphansCalls == [alice.id, bob.id])
        #expect(fixture.personRepository.fetchAllCallCount == 1)
    }

    @Test("runCleanup is a no-op when primary key is unavailable")
    func runCleanup_noPrimaryKey() async throws {
        let fixture = Self.makeFixture()
        fixture.primaryKeyProvider.shouldFail = true
        try fixture.personRepository.addPerson(Person(name: "Alice"))

        await fixture.coordinator.runCleanup()

        #expect(fixture.cleanupService.cleanOrphansCalls.isEmpty)
        // Must not even reach fetchAll when the key is unavailable
        #expect(fixture.personRepository.fetchAllCallCount == 0)
    }

    @Test("runCleanup continues if one person's cleanup fails")
    func runCleanup_perPersonResilience() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Person(name: "Alice"))
        try fixture.personRepository.addPerson(Person(name: "Bob"))
        fixture.cleanupService.cleanOrphansError = RepositoryError.saveFailed("mock failure")

        await fixture.coordinator.runCleanup()

        // Both persons still get attempted — sibling failures must not block the sweep
        #expect(fixture.cleanupService.cleanOrphansCalls.count == 2)
    }

    // MARK: - Defensive Day-1 Tests

    @Test("runCleanup with zero persons exits cleanly and invokes no cleanup")
    func runCleanup_noPersons_stillExitsCleanly() async {
        let fixture = Self.makeFixture()

        await fixture.coordinator.runCleanup()

        #expect(fixture.cleanupService.cleanOrphansCalls.isEmpty)
        #expect(fixture.personRepository.fetchAllCallCount == 1)
    }

    @Test("runCleanup is a no-op when fetchAll throws")
    func runCleanup_fetchAllFails_isNoOp() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Person(name: "Alice"))
        fixture.personRepository.shouldFailFetchAll = true

        await fixture.coordinator.runCleanup()

        #expect(fixture.cleanupService.cleanOrphansCalls.isEmpty)
        #expect(fixture.personRepository.fetchAllCallCount == 1)
    }

    @Test("runCleanup completes cleanly when cleanup reports orphans freed (info-log path)")
    func runCleanup_logsSummaryOnSuccess() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Person(name: "Alice"))
        fixture.cleanupService.cleanOrphansResult = CleanupResult(orphanCount: 3, freedBytes: 1_024)

        await fixture.coordinator.runCleanup()

        // The coordinator must exercise the info-log branch (orphanCount > 0) without crashing
        #expect(fixture.cleanupService.cleanOrphansCalls.count == 1)
    }
}
