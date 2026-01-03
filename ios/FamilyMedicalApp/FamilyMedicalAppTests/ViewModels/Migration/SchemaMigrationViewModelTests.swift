import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Shared Test Helpers

private func makePerson() throws -> Person { try Person(name: "Test Person") }

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
        transformations: [.typeConvert(fieldId: "number", toType: .int)]
    )
}

// MARK: - Initialization & Computed Properties Tests

@MainActor
struct SchemaMigrationViewModelInitTests {
    @Test("Initializes with correct default values")
    func initializationDefaults() throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(viewModel.phase == .idle)
        #expect(viewModel.preview == nil)
        #expect(viewModel.progress == nil)
        #expect(viewModel.result == nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.didComplete)
    }

    @Test("Title reflects schema ID")
    func titleReflectsSchemaId() throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(viewModel.title == "Migrate test-schema")
    }

    @Test("hasMerges returns true when migration has merge transformations")
    func hasMergesTrue() throws {
        let person = try makePerson()
        let migration = try makeMigrationWithMerge()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(viewModel.hasMerges)
    }

    @Test("hasMerges returns false when migration has no merge transformations")
    func hasMergesFalse() throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(!viewModel.hasMerges)
    }

    @Test("hasTypeConversions returns true when migration has type conversions")
    func hasTypeConversionsTrue() throws {
        let person = try makePerson()
        let migration = try makeMigrationWithTypeConvert()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(viewModel.hasTypeConversions)
    }

    @Test("hasTypeConversions returns false when migration has no type conversions")
    func hasTypeConversionsFalse() throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        #expect(!viewModel.hasTypeConversions)
    }

    @Test("currentMergeStrategy uses concatenateSeparator")
    func currentMergeStrategyUsesSeparator() throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        viewModel.concatenateSeparator = ", "
        let strategy = viewModel.currentMergeStrategy

        if case let .concatenate(separator) = strategy {
            #expect(separator == ", ")
        } else {
            Issue.record("Expected concatenate strategy")
        }
    }
}

// MARK: - Load Preview & Execute Migration Tests

@MainActor
struct SchemaMigrationViewModelOperationTests {
    @Test("loadPreview sets phase to loadingPreview then showingPreview")
    func loadPreviewPhases() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.previewToReturn = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPreview()

        #expect(viewModel.phase == .showingPreview)
        #expect(viewModel.preview?.recordCount == 5)
        #expect(!viewModel.isLoading)
    }

    @Test("loadPreview sets failed phase on error")
    func loadPreviewFailed() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.shouldFailPreview = true

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPreview()

        #expect(viewModel.phase == .failed)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
    }

    @Test("executeMigration sets phase to migrating then completed on success")
    func executeMigrationSuccess() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.resultToReturn = MigrationResult(
            migration: migration,
            recordsProcessed: 5,
            recordsSucceeded: 5,
            recordsFailed: 0,
            errors: [],
            startTime: Date(),
            endTime: Date()
        )

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.executeMigration()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.didComplete)
        #expect(viewModel.result?.isSuccess == true)
        #expect(!viewModel.isLoading)
    }

    @Test("executeMigration sets failed phase when result has errors")
    func executeMigrationWithErrors() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.resultToReturn = MigrationResult(
            migration: migration,
            recordsProcessed: 5,
            recordsSucceeded: 3,
            recordsFailed: 2,
            errors: [
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 1"),
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error 2")
            ],
            startTime: Date(),
            endTime: Date()
        )

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.executeMigration()

        #expect(viewModel.phase == .failed)
        #expect(!viewModel.didComplete)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("executeMigration sets failed phase on exception")
    func executeMigrationException() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.shouldFailExecute = true

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.executeMigration()

        #expect(viewModel.phase == .failed)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
    }

    @Test("executeMigration uses selected merge strategy")
    func executeMigrationUsesSelectedStrategy() async throws {
        let person = try makePerson()
        let migration = try makeMigrationWithMerge()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.resultToReturn = MigrationResult(
            migration: migration,
            recordsProcessed: 1,
            recordsSucceeded: 1,
            recordsFailed: 0,
            errors: [],
            startTime: Date(),
            endTime: Date()
        )

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        viewModel.mergeStrategy = .preferSource
        await viewModel.executeMigration()

        #expect(mockService.executeCalled)
    }

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let person = try makePerson()
        let migration = try makeMigration()
        let mockService = MockSchemaMigrationService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        mockService.previewToReturn = MigrationPreview(recordCount: 5, sampleRecordId: UUID(), warnings: [])
        mockService.resultToReturn = MigrationResult(
            migration: migration,
            recordsProcessed: 5,
            recordsSucceeded: 5,
            recordsFailed: 0,
            errors: [],
            startTime: Date(),
            endTime: Date()
        )

        let viewModel = SchemaMigrationViewModel(
            person: person, migration: migration, migrationService: mockService, primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPreview()
        await viewModel.executeMigration()
        viewModel.reset()

        #expect(viewModel.phase == .idle)
        #expect(viewModel.preview == nil)
        #expect(viewModel.progress == nil)
        #expect(viewModel.result == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.didComplete)
    }
}

// MARK: - Mock Services

final class MockSchemaMigrationService: SchemaMigrationServiceProtocol, @unchecked Sendable {
    var shouldFailPreview = false
    var shouldFailExecute = false
    var previewToReturn = MigrationPreview(recordCount: 0, sampleRecordId: nil, warnings: [])
    var resultToReturn: MigrationResult?
    var previewCalled = false
    var executeCalled = false

    func previewMigration(
        _ migration: SchemaMigration, forPerson personId: UUID, primaryKey: SymmetricKey
    ) async throws -> MigrationPreview {
        previewCalled = true
        if shouldFailPreview { throw RepositoryError.fetchFailed("Mock preview failed") }
        return previewToReturn
    }

    func executeMigration(
        _ migration: SchemaMigration,
        forPerson personId: UUID,
        primaryKey: SymmetricKey,
        options: MigrationOptions,
        progressHandler: @escaping @Sendable (MigrationProgress) -> Void
    ) async throws -> MigrationResult {
        executeCalled = true
        if shouldFailExecute { throw RepositoryError.migrationFailed("Mock execute failed") }

        progressHandler(MigrationProgress(totalRecords: 5, processedRecords: 0, currentRecordId: nil))
        progressHandler(MigrationProgress(totalRecords: 5, processedRecords: 5, currentRecordId: nil))

        guard let result = resultToReturn else {
            return MigrationResult(
                migration: migration,
                recordsProcessed: 0,
                recordsSucceeded: 0,
                recordsFailed: 0,
                errors: [],
                startTime: Date(),
                endTime: Date()
            )
        }
        return result
    }
}

// MockPrimaryKeyProvider is defined in MockServices.swift
