import CryptoKit
import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for SchemaMigrationView
@MainActor
struct SchemaMigrationViewTests {
    // MARK: - Test Helpers

    private func makePerson() throws -> Person {
        try Person(name: "Test Person")
    }

    private func makeMigration() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "obsoleteField")]
        )
    }

    private func makeMigrationWithMerge() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: "firstName", into: "fullName")]
        )
    }

    private func makeMigrationWithTypeConvert() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: "age", toType: .int)]
        )
    }

    private func makeViewModel(
        migration: SchemaMigration? = nil
    ) throws -> SchemaMigrationViewModel {
        let person = try makePerson()
        let mig = try migration ?? makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))
        return SchemaMigrationViewModel(
            person: person,
            migration: mig,
            migrationService: mockService,
            primaryKeyProvider: mockKeyProvider
        )
    }

    // MARK: - Initialization Tests

    @Test("View initializes correctly")
    func viewInitializes() throws {
        let person = try makePerson()
        let migration = try makeMigration()

        let view = SchemaMigrationView(person: person, migration: migration)
        _ = view.body
    }

    @Test("View initializes with ViewModel")
    func viewInitializesWithViewModel() throws {
        let viewModel = try makeViewModel()
        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View initializes with completion handler")
    func viewInitializesWithCompletion() throws {
        let viewModel = try makeViewModel()
        var completionCalled = false

        let view = SchemaMigrationView(viewModel: viewModel) {
            completionCalled = true
        }

        _ = view.body
        #expect(!completionCalled)
    }

    // MARK: - Idle Phase Tests

    @Test("View renders idle phase as loading")
    func viewRendersIdlePhase() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.phase == .idle)

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Loading Preview Phase Tests

    @Test("View renders loading preview phase")
    func viewRendersLoadingPreviewPhase() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .loadingPreview

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Showing Preview Phase Tests

    @Test("View renders showing preview phase")
    func viewRendersShowingPreviewPhase() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders preview with warnings")
    func viewRendersPreviewWithWarnings() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(
            recordCount: 10,
            sampleRecordId: UUID(),
            warnings: ["Warning 1", "Warning 2"]
        )

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders preview with zero records")
    func viewRendersPreviewWithZeroRecords() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 0, sampleRecordId: nil, warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders preview with merge options")
    func viewRendersPreviewWithMergeOptions() throws {
        let migration = try makeMigrationWithMerge()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        #expect(viewModel.hasMerges)
        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders preview with concatenate strategy")
    func viewRendersPreviewWithConcatenateStrategy() throws {
        let migration = try makeMigrationWithMerge()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .concatenate(separator: ", ")
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Confirming Phase Tests

    @Test("View renders confirming phase as preview")
    func viewRendersConfirmingPhase() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .confirming
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Migrating Phase Tests

    @Test("View renders migrating phase with progress")
    func viewRendersMigratingPhase() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .migrating
        viewModel.progress = MigrationProgress(totalRecords: 10, processedRecords: 5, currentRecordId: UUID())

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders migrating phase without progress")
    func viewRendersMigratingPhaseWithoutProgress() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .migrating
        viewModel.progress = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Completed Phase Tests

    @Test("View renders completed phase with success")
    func viewRendersCompletedPhaseWithSuccess() throws {
        let migration = try makeMigration()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .completed
        viewModel.result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 10,
            recordsFailed: 0,
            errors: [],
            startTime: Date(),
            endTime: Date()
        )

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders completed phase with failures")
    func viewRendersCompletedPhaseWithFailures() throws {
        let migration = try makeMigration()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .completed
        viewModel.result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 8,
            recordsFailed: 2,
            errors: [
                MigrationRecordError(recordId: UUID(), fieldId: "field", reason: "Error 1"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 2")
            ],
            startTime: Date(),
            endTime: Date()
        )

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders completed phase without result")
    func viewRendersCompletedPhaseWithoutResult() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .completed
        viewModel.result = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Failed Phase Tests

    @Test("View renders failed phase with error message")
    func viewRendersFailedPhaseWithError() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .failed
        viewModel.errorMessage = "Something went wrong"

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders failed phase with error list")
    func viewRendersFailedPhaseWithErrorList() throws {
        let migration = try makeMigration()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .failed
        viewModel.errorMessage = "Migration failed"
        viewModel.result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 5,
            recordsFailed: 5,
            errors: [
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 1"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 2"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 3"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 4"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 5"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 6")
            ],
            startTime: Date(),
            endTime: Date()
        )

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders failed phase without error message")
    func viewRendersFailedPhaseWithoutErrorMessage() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .failed
        viewModel.errorMessage = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Type Conversion Tests

    @Test("View renders with type conversion migration")
    func viewRendersWithTypeConversion() throws {
        let migration = try makeMigrationWithTypeConvert()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        #expect(viewModel.hasTypeConversions)
        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - MergeStrategy Variations

    @Test("View renders with preferSource strategy")
    func viewRendersWithPreferSourceStrategy() throws {
        let migration = try makeMigrationWithMerge()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .preferSource
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    @Test("View renders with preferTarget strategy")
    func viewRendersWithPreferTargetStrategy() throws {
        let migration = try makeMigrationWithMerge()
        let viewModel = try makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .preferTarget
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }

    // MARK: - Loading State Tests

    @Test("View reflects migrating phase as loading")
    func viewReflectsMigratingPhaseAsLoading() throws {
        let viewModel = try makeViewModel()
        viewModel.phase = .migrating

        // Migrating phase should be reflected in the view
        let view = SchemaMigrationView(viewModel: viewModel)
        _ = view.body
    }
}
