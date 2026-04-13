import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("SettingsViewModel Storage Cleanup Tests")
struct SettingsViewModelCleanupTests {
    // MARK: - Fixture

    /// Bundle of collaborators wired for cleanup tests. Keeping references to the mocks
    /// lets each test assert against call counts / configure stub values.
    @MainActor
    struct Fixture {
        let viewModel: SettingsViewModel
        let cleanupService: MockOrphanBlobCleanupService
        let personRepository: MockPersonRepository
    }

    @MainActor
    static func makeFixture() -> Fixture {
        let cleanupService = MockOrphanBlobCleanupService()
        let personRepository = MockPersonRepository()
        let viewModel = SettingsViewModel(
            exportService: MockExportService(),
            importService: MockImportService(),
            backupFileService: MockBackupFileService(),
            logExportService: MockLogExportService(),
            cleanupService: cleanupService,
            personRepository: personRepository
        )
        return Fixture(
            viewModel: viewModel,
            cleanupService: cleanupService,
            personRepository: personRepository
        )
    }

    /// Build a persisted `Person` for repository setup. Person's init throws so tests
    /// use `try` and a guaranteed-valid name.
    static func makePerson(name: String = "Alice") throws -> Person {
        try Person(name: name)
    }

    // MARK: - checkStorage Happy Paths

    @Test("checkStorage aggregates orphan counts across persons and shows confirmation when orphans exist")
    @MainActor
    func checkStorage_withOrphans() async throws {
        let fixture = Self.makeFixture()
        let personA = try Self.makePerson(name: "Alice")
        let personB = try Self.makePerson(name: "Bob")
        fixture.personRepository.addPerson(personA)
        fixture.personRepository.addPerson(personB)
        fixture.cleanupService.countOrphansResult = CleanupResult(orphanCount: 2, freedBytes: 1_024)

        let primaryKey = SymmetricKey(size: .bits256)
        await fixture.viewModel.checkStorage(primaryKey: primaryKey)

        // Persons come back sorted by name, so Alice then Bob
        #expect(fixture.cleanupService.countOrphansCalls == [personA.id, personB.id])
        #expect(fixture.viewModel.cleanupDryRunResult?.orphanCount == 4)
        #expect(fixture.viewModel.cleanupDryRunResult?.freedBytes == 2_048)
        #expect(fixture.viewModel.showingCleanupConfirmation)
        #expect(!fixture.viewModel.showingCleanupResult)
        #expect(!fixture.viewModel.isCheckingStorage)
    }

    @Test("checkStorage shows result directly when no orphans exist")
    @MainActor
    func checkStorage_noOrphans() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Self.makePerson())
        fixture.cleanupService.countOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)

        await fixture.viewModel.checkStorage(primaryKey: SymmetricKey(size: .bits256))

        #expect(!fixture.viewModel.showingCleanupConfirmation)
        #expect(fixture.viewModel.showingCleanupResult)
        #expect(fixture.viewModel.cleanupResult?.orphanCount == 0)
    }

    // MARK: - performCleanup Happy Paths

    @Test("performCleanup aggregates cleanOrphans results and shows result alert")
    @MainActor
    func performCleanup_success() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Self.makePerson())
        fixture.cleanupService.cleanOrphansResult = CleanupResult(orphanCount: 3, freedBytes: 4_096)

        await fixture.viewModel.performCleanup(primaryKey: SymmetricKey(size: .bits256))

        #expect(fixture.cleanupService.cleanOrphansCalls.count == 1)
        #expect(fixture.viewModel.cleanupResult?.orphanCount == 3)
        #expect(fixture.viewModel.cleanupResult?.freedBytes == 4_096)
        #expect(fixture.viewModel.showingCleanupResult)
        #expect(!fixture.viewModel.showingCleanupConfirmation)
        #expect(!fixture.viewModel.isCleaningStorage)
    }

    @Test("performCleanup surfaces error message on cleanupService failure")
    @MainActor
    func performCleanup_failure() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Self.makePerson())
        fixture.cleanupService.cleanOrphansError = RepositoryError.saveFailed("disk locked")

        await fixture.viewModel.performCleanup(primaryKey: SymmetricKey(size: .bits256))

        #expect(fixture.viewModel.errorMessage == "Some files could not be cleaned up.")
        #expect(!fixture.viewModel.showingCleanupResult)
        #expect(!fixture.viewModel.isCleaningStorage)
    }

    // MARK: - Defensive Tests

    @Test("checkStorage surfaces error when personRepository fails")
    @MainActor
    func checkStorage_personRepositoryFailure() async {
        let fixture = Self.makeFixture()
        fixture.personRepository.shouldFailFetchAll = true

        await fixture.viewModel.checkStorage(primaryKey: SymmetricKey(size: .bits256))

        #expect(fixture.viewModel.errorMessage == "Unable to check storage. Please try again.")
        #expect(!fixture.viewModel.showingCleanupConfirmation)
        #expect(!fixture.viewModel.showingCleanupResult)
    }

    @Test("checkStorage surfaces error when countOrphans fails")
    @MainActor
    func checkStorage_countOrphansFailure() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Self.makePerson())
        fixture.cleanupService.countOrphansError = RepositoryError.fetchFailed("disk error")

        await fixture.viewModel.checkStorage(primaryKey: SymmetricKey(size: .bits256))

        #expect(fixture.viewModel.errorMessage == "Unable to check storage. Please try again.")
        #expect(!fixture.viewModel.showingCleanupConfirmation)
    }

    @Test("checkStorage clears stale dryRunResult before running")
    @MainActor
    func checkStorage_clearsStaleDryRun() async {
        let fixture = Self.makeFixture()
        fixture.viewModel.cleanupDryRunResult = CleanupResult(orphanCount: 99, freedBytes: 99_999)
        // No persons — loop is skipped, and aggregate should settle at 0/0 (not 99/99_999).
        fixture.cleanupService.countOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)

        await fixture.viewModel.checkStorage(primaryKey: SymmetricKey(size: .bits256))

        #expect(fixture.viewModel.cleanupDryRunResult?.orphanCount == 0)
        #expect(fixture.viewModel.cleanupDryRunResult?.freedBytes == 0)
    }

    @Test("performCleanup cleanupResult does not reflect stale cleanupDryRunResult when totals diverge")
    @MainActor
    func performCleanup_cleanupResultIsolatedFromDryRun() async throws {
        let fixture = Self.makeFixture()
        try fixture.personRepository.addPerson(Self.makePerson(name: "Alice"))

        // Dry-run finds 5 orphans, 2048 bytes
        fixture.cleanupService.countOrphansResult = CleanupResult(orphanCount: 5, freedBytes: 2_048)
        await fixture.viewModel.checkStorage(primaryKey: SymmetricKey(size: .bits256))
        #expect(fixture.viewModel.cleanupDryRunResult?.orphanCount == 5)
        #expect(fixture.viewModel.cleanupDryRunResult?.freedBytes == 2_048)

        // But the real cleanup only frees 3 orphans / 1024 bytes (partial failure or race)
        fixture.cleanupService.cleanOrphansResult = CleanupResult(orphanCount: 3, freedBytes: 1_024)
        await fixture.viewModel.performCleanup(primaryKey: SymmetricKey(size: .bits256))

        // cleanupResult must reflect the real cleanup, not the dry-run
        #expect(fixture.viewModel.cleanupResult?.orphanCount == 3)
        #expect(fixture.viewModel.cleanupResult?.freedBytes == 1_024)
    }
}
