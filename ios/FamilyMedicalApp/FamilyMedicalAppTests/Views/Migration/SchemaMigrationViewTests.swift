import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

// MARK: - Shared Test Helpers

@MainActor
enum SchemaMigrationTestHelpers {
    static func makePerson() throws -> Person {
        try Person(name: "Test Person")
    }

    static func makeMigration() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "obsoleteField")]
        )
    }

    static func makeMigrationWithMerge() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: "firstName", into: "fullName")]
        )
    }

    static func makeMigrationWithTypeConvert() throws -> SchemaMigration {
        try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: "age", toType: .int)]
        )
    }

    static func makeViewModel(migration: SchemaMigration? = nil) throws -> SchemaMigrationViewModel {
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
}

// MARK: - Initialization & Basic Phase Tests

@MainActor
@Suite("SchemaMigrationView Initialization")
struct SchemaMigrationViewInitializationTests {
    @Test("View initializes correctly")
    func viewInitializes() throws {
        let person = try SchemaMigrationTestHelpers.makePerson()
        let migration = try SchemaMigrationTestHelpers.makeMigration()

        let view = SchemaMigrationView(person: person, migration: migration)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    @Test("View initializes with ViewModel")
    func viewInitializesWithViewModel() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    @Test("View initializes with completion handler")
    func viewInitializesWithCompletion() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        var completionCalled = false

        let view = SchemaMigrationView(viewModel: viewModel) {
            completionCalled = true
        }

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(!completionCalled)
    }

    @Test("View renders idle phase as loading")
    func viewRendersIdlePhase() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        #expect(viewModel.phase == .idle)

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test("View renders loading preview phase")
    func viewRendersLoadingPreviewPhase() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .loadingPreview

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
        _ = try inspected.find(text: "Loading preview...")
    }
}

// MARK: - Preview Phase Tests

@MainActor
@Suite("SchemaMigrationView Preview Phase")
struct SchemaMigrationViewPreviewTests {
    @Test("View renders showing preview phase")
    func viewRendersShowingPreviewPhase() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Migration Summary")
    }

    @Test("View renders preview with warnings")
    func viewRendersPreviewWithWarnings() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(
            recordCount: 10,
            sampleRecordId: UUID(),
            warnings: ["Warning 1", "Warning 2"]
        )

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Warnings")
        _ = try inspected.find(text: "Warning 1")
    }

    @Test("View renders preview with zero records")
    func viewRendersPreviewWithZeroRecords() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 0, sampleRecordId: nil, warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "0")
    }

    @Test("View renders preview with merge options")
    func viewRendersPreviewWithMergeOptions() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigrationWithMerge()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        #expect(viewModel.hasMerges)
        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Merge Options")
    }

    @Test("View renders preview with concatenate strategy")
    func viewRendersPreviewWithConcatenateStrategy() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigrationWithMerge()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .concatenate(separator: ", ")
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(ViewType.TextField.self)
    }

    @Test("View renders confirming phase as preview")
    func viewRendersConfirmingPhase() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .confirming
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Migration Summary")
    }
}

// MARK: - Migrating & Completed Phase Tests

@MainActor
@Suite("SchemaMigrationView Migrating & Completed Phases")
struct SchemaMigrationViewMigratingCompletedTests {
    @Test("View renders migrating phase with progress")
    func viewRendersMigratingPhase() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .migrating
        viewModel.progress = MigrationProgress(totalRecords: 10, processedRecords: 5, currentRecordId: UUID())

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
        _ = try inspected.find(text: "Migrating records...")
        _ = try inspected.find(text: "5 of 10")
    }

    @Test("View renders migrating phase without progress")
    func viewRendersMigratingPhaseWithoutProgress() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .migrating
        viewModel.progress = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
        _ = try inspected.find(text: "Migrating records...")
    }

    @Test("View reflects migrating phase as loading")
    func viewReflectsMigratingPhaseAsLoading() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .migrating

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
        _ = try inspected.find(text: "Please wait. Do not close the app.")
    }

    @Test("View renders completed phase with success")
    func viewRendersCompletedPhaseWithSuccess() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigration()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
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
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "Migration Complete")
        _ = try inspected.find(text: "10 records migrated successfully")
    }

    @Test("View renders completed phase with failures")
    func viewRendersCompletedPhaseWithFailures() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigration()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
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
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Migration Complete")
        _ = try inspected.find(text: "8 records migrated successfully")
        _ = try inspected.find(text: "2 records failed")
    }

    @Test("View renders completed phase without result")
    func viewRendersCompletedPhaseWithoutResult() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .completed
        viewModel.result = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Migration Complete")
        _ = try inspected.find(ViewType.Button.self)
    }
}

// MARK: - Failed Phase & Strategy Tests

@MainActor
@Suite("SchemaMigrationView Failed Phase & Strategies")
struct SchemaMigrationViewFailedStrategyTests {
    @Test("View renders failed phase with error message")
    func viewRendersFailedPhaseWithError() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .failed
        viewModel.errorMessage = "Something went wrong"

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "Migration Failed")
        _ = try inspected.find(text: "Something went wrong")
    }

    @Test("View renders failed phase with error list")
    func viewRendersFailedPhaseWithErrorList() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigration()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
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
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Migration Failed")
        _ = try inspected.find(text: "• Error 1")
        _ = try inspected.find(text: "... and 1 more errors")
    }

    @Test("View renders failed phase without error message")
    func viewRendersFailedPhaseWithoutErrorMessage() throws {
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel()
        viewModel.phase = .failed
        viewModel.errorMessage = nil

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Migration Failed")
        _ = try inspected.find(text: "Try Again")
    }

    @Test("View renders with type conversion migration")
    func viewRendersWithTypeConversion() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigrationWithTypeConvert()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.preview = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        #expect(viewModel.hasTypeConversions)
        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Migration Summary")
    }

    @Test("View renders with preferSource strategy")
    func viewRendersWithPreferSourceStrategy() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigrationWithMerge()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .preferSource
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Merge Options")
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    @Test("View renders with preferTarget strategy")
    func viewRendersWithPreferTargetStrategy() throws {
        let migration = try SchemaMigrationTestHelpers.makeMigrationWithMerge()
        let viewModel = try SchemaMigrationTestHelpers.makeViewModel(migration: migration)
        viewModel.phase = .showingPreview
        viewModel.mergeStrategy = .preferTarget
        viewModel.preview = MigrationPreview(recordCount: 3, sampleRecordId: UUID(), warnings: [])

        let view = SchemaMigrationView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        _ = try inspected.find(text: "Merge Options")
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.TextField.self)
        }
    }
}
