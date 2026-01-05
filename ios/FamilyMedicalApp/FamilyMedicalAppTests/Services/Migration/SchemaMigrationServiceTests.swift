import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Helper struct to avoid large tuple SwiftLint violation
private struct TestMocks {
    let recordRepo: MockMedicalRecordRepository
    let contentService: MockRecordContentService
    let checkpointService: MockMigrationCheckpointService
    let fmkService: MockFamilyMemberKeyService

    init() {
        self.recordRepo = MockMedicalRecordRepository()
        self.contentService = MockRecordContentService()
        self.checkpointService = MockMigrationCheckpointService()
        self.fmkService = MockFamilyMemberKeyService()
    }

    func makeService() -> SchemaMigrationService {
        SchemaMigrationService(
            medicalRecordRepository: recordRepo,
            recordContentService: contentService,
            checkpointService: checkpointService,
            fmkService: fmkService
        )
    }
}

// MARK: - Preview Migration Tests

struct SchemaMigrationServicePreviewTests {
    private func makeMocks() -> TestMocks { TestMocks() }

    private func makeTestRecord(personId: UUID, content: RecordContent) throws -> MedicalRecord {
        let encoder = JSONEncoder()
        let contentData = try encoder.encode(content)
        return MedicalRecord(personId: personId, encryptedContent: Data(contentData.reversed()))
    }

    private func makeTestContent(
        schemaId: String = "test-schema",
        fields: [UUID: FieldValue] = [:]
    ) -> RecordContent {
        var content = RecordContent(schemaId: schemaId)
        for (key, value) in fields {
            content[key] = value
        }
        return content
    }

    /// Test field UUIDs for migration tests
    private static let field1Id = UUID()
    private static let numberId = UUID()

    @Test("Preview returns correct record count")
    func previewRecordCount() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content1 = makeTestContent(schemaId: "test-schema", fields: [Self.field1Id: .string("value1")])
        let content2 = makeTestContent(schemaId: "test-schema", fields: [Self.field1Id: .string("value2")])
        let content3 = makeTestContent(schemaId: "other-schema", fields: [Self.field1Id: .string("value3")])

        let record1 = try makeTestRecord(personId: personId, content: content1)
        let record2 = try makeTestRecord(personId: personId, content: content2)
        let record3 = try makeTestRecord(personId: personId, content: content3)

        mocks.recordRepo.addRecord(record1)
        mocks.recordRepo.addRecord(record2)
        mocks.recordRepo.addRecord(record3)
        mocks.contentService.setContent(content1, for: record1.encryptedContent)
        mocks.contentService.setContent(content2, for: record2.encryptedContent)
        mocks.contentService.setContent(content3, for: record3.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: Self.field1Id.uuidString)]
        )

        let preview = try await service.previewMigration(migration, forPerson: personId, primaryKey: primaryKey)
        #expect(preview.recordCount == 2)
        #expect(preview.sampleRecordId != nil)
    }

    @Test("Preview generates warnings for invalid conversions")
    func previewGeneratesWarnings() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "test-schema", fields: [Self.numberId: .string("not a number")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: Self.numberId.uuidString, toType: .int)]
        )

        let preview = try await service.previewMigration(migration, forPerson: personId, primaryKey: primaryKey)
        #expect(!preview.warnings.isEmpty)
        #expect(preview.warnings.first?.contains(Self.numberId.uuidString) == true)
    }
}

// MARK: - Execute Migration Tests

struct SchemaMigrationServiceExecuteTests {
    private func makeMocks() -> TestMocks { TestMocks() }

    private func makeTestRecord(personId: UUID, content: RecordContent) throws -> MedicalRecord {
        let encoder = JSONEncoder()
        let contentData = try encoder.encode(content)
        return MedicalRecord(personId: personId, encryptedContent: Data(contentData.reversed()))
    }

    private func makeTestContent(
        schemaId: String = "test-schema",
        fields: [UUID: FieldValue] = [:]
    ) -> RecordContent {
        var content = RecordContent(schemaId: schemaId)
        for (key, value) in fields {
            content[key] = value
        }
        return content
    }

    /// Test field UUIDs for migration tests
    private static let keepId = UUID()
    private static let removeId = UUID()
    private static let numberId = UUID()
    private static let firstId = UUID()
    private static let lastId = UUID()
    private static let fullNameId = UUID()
    private static let fieldId = UUID()

    @Test("Execute migration removes fields")
    func executeRemoveField() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(
            schemaId: "test-schema",
            fields: [Self.keepId: .string("value"), Self.removeId: .string("delete me")]
        )
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: Self.removeId.uuidString)]
        )

        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        #expect(result.isSuccess)
        #expect(result.recordsProcessed == 1)
        #expect(result.recordsSucceeded == 1)
        #expect(mocks.checkpointService.createCheckpointCalled)
        #expect(mocks.checkpointService.deleteCheckpointCalled)
    }

    @Test("Execute migration converts string to int")
    func executeTypeConvert() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "test-schema", fields: [Self.numberId: .string("42")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: Self.numberId.uuidString, toType: .int)]
        )

        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        #expect(result.isSuccess)
        #expect(mocks.contentService.encryptCallCount == 1)
    }

    @Test("Execute migration creates and deletes checkpoint")
    func executeCreatesAndDeletesCheckpoint() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "test-schema", fields: [Self.fieldId: .string("value")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: Self.fieldId.uuidString)]
        )

        _ = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        #expect(mocks.checkpointService.createCheckpointCalled)
        #expect(mocks.checkpointService.deleteCheckpointCalled)
        #expect(!mocks.checkpointService.restoreCheckpointCalled)
    }

    @Test("Execute migration reports progress")
    func executeReportsProgress() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        // Use unique field IDs for each record
        let dynamicFieldIds = [UUID(), UUID(), UUID()]
        for idx in 0 ..< 3 {
            let content = makeTestContent(
                schemaId: "test-schema",
                fields: [dynamicFieldIds[idx]: .string("value\(idx)")]
            )
            let record = try makeTestRecord(personId: personId, content: content)
            mocks.recordRepo.addRecord(record)
            mocks.contentService.setContent(content, for: record.encryptedContent)
        }

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: dynamicFieldIds[0].uuidString)]
        )

        let progressCollector = ProgressCollector()
        _ = try await service.executeMigration(
            migration, forPerson: personId, primaryKey: primaryKey, options: .default
        ) { progressCollector.add($0) }

        #expect(progressCollector.count >= 3)
        #expect(progressCollector.first?.totalRecords == 3)
    }

    @Test("Execute migration with no matching records succeeds with zero count")
    func executeNoMatchingRecords() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "other-schema", fields: [Self.fieldId: .string("value")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: Self.fieldId.uuidString)]
        )

        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        #expect(result.isSuccess)
        #expect(result.recordsProcessed == 0)
    }

    @Test("Type conversion failure keeps original value")
    func typeConversionFailureKeepsOriginal() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "test-schema", fields: [Self.numberId: .string("not a number")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: Self.numberId.uuidString, toType: .int)]
        )

        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        #expect(result.isSuccess)
    }

    @Test("Execute migration with errors triggers rollback before delete")
    func executeWithErrorsTriggersRollback() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(schemaId: "test-schema", fields: [Self.fieldId: .string("value")])
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        // Configure the content service to fail on encrypt (simulates error during migration)
        mocks.contentService.shouldFailEncrypt = true

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: Self.fieldId.uuidString)]
        )

        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: .default
        ) { _ in }

        // Migration should report the error
        #expect(!result.isSuccess)
        #expect(result.recordsFailed == 1)

        // Checkpoint operations: create -> rollback -> delete
        #expect(mocks.checkpointService.createCheckpointCalled)
        #expect(mocks.checkpointService.restoreCheckpointCalled)
        #expect(mocks.checkpointService.deleteCheckpointCalled)
    }
}

// MARK: - Merge Migration Tests

struct SchemaMigrationServiceMergeTests {
    private func makeMocks() -> TestMocks { TestMocks() }

    private func makeTestRecord(personId: UUID, content: RecordContent) throws -> MedicalRecord {
        let encoder = JSONEncoder()
        let contentData = try encoder.encode(content)
        return MedicalRecord(personId: personId, encryptedContent: Data(contentData.reversed()))
    }

    private func makeTestContent(
        schemaId: String = "test-schema",
        fields: [UUID: FieldValue] = [:]
    ) -> RecordContent {
        var content = RecordContent(schemaId: schemaId)
        for (key, value) in fields {
            content[key] = value
        }
        return content
    }

    /// Test field UUIDs for merge tests
    private static let firstId = UUID()
    private static let lastId = UUID()
    private static let fullNameId = UUID()

    @Test("Execute migration merges fields with concatenate")
    func executeMergeConcatenate() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(
            schemaId: "test-schema",
            fields: [Self.firstId: .string("John"), Self.lastId: .string("Doe")]
        )
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: Self.firstId.uuidString, into: Self.fullNameId.uuidString)]
        )

        let options = MigrationOptions(mergeStrategy: .concatenate(separator: " "))
        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: options
        ) { _ in }

        #expect(result.isSuccess)
    }

    @Test("Execute migration with preferTarget preserves existing target value")
    func executeMergePreferTargetPreservesExisting() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(
            schemaId: "test-schema",
            fields: [
                Self.firstId: .string("John"),
                Self.lastId: .string("Doe"),
                Self.fullNameId: .string("Existing Name")
            ]
        )
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: Self.firstId.uuidString, into: Self.fullNameId.uuidString)]
        )

        let options = MigrationOptions(mergeStrategy: .preferTarget)
        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: options
        ) { _ in }

        #expect(result.isSuccess)
    }

    @Test("Execute migration with preferSource overwrites existing target value")
    func executeMergePreferSourceOverwrites() async throws {
        let mocks = makeMocks()
        let service = mocks.makeService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        mocks.fmkService.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)

        let content = makeTestContent(
            schemaId: "test-schema",
            fields: [
                Self.firstId: .string("John"),
                Self.lastId: .string("Doe"),
                Self.fullNameId: .string("Existing Name")
            ]
        )
        let record = try makeTestRecord(personId: personId, content: content)
        mocks.recordRepo.addRecord(record)
        mocks.contentService.setContent(content, for: record.encryptedContent)

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: Self.firstId.uuidString, into: Self.fullNameId.uuidString)]
        )

        let options = MigrationOptions(mergeStrategy: .preferSource)
        let result = try await service.executeMigration(
            migration,
            forPerson: personId,
            primaryKey: primaryKey,
            options: options
        ) { _ in }

        #expect(result.isSuccess)
    }
}

// MARK: - Mock Checkpoint Service

final class MockMigrationCheckpointService: MigrationCheckpointServiceProtocol, @unchecked Sendable {
    var shouldFailCreate = false
    var shouldFailRestore = false
    var shouldFailDelete = false
    var createCheckpointCalled = false
    var restoreCheckpointCalled = false
    var deleteCheckpointCalled = false
    private var checkpoints: [UUID: [MedicalRecord]] = [:]

    func createCheckpoint(migrationId: UUID, personId: UUID, schemaId: String, records: [MedicalRecord]) async throws {
        createCheckpointCalled = true
        if shouldFailCreate { throw RepositoryError.saveFailed("Mock create checkpoint failed") }
        checkpoints[migrationId] = records
    }

    func restoreCheckpoint(migrationId: UUID) async throws -> [MedicalRecord] {
        restoreCheckpointCalled = true
        if shouldFailRestore { throw RepositoryError.checkpointNotFound(migrationId) }
        return checkpoints[migrationId] ?? []
    }

    func deleteCheckpoint(migrationId: UUID) async throws {
        deleteCheckpointCalled = true
        if shouldFailDelete { throw RepositoryError.deleteFailed("Mock delete checkpoint failed") }
        checkpoints.removeValue(forKey: migrationId)
    }

    func hasCheckpoint(migrationId: UUID) async throws -> Bool { checkpoints[migrationId] != nil }
}

// MARK: - Progress Collector (Thread-safe)

final class ProgressCollector: @unchecked Sendable {
    private var updates: [MigrationProgress] = []
    private let lock = NSLock()

    func add(_ progress: MigrationProgress) {
        lock.lock()
        defer { lock.unlock() }
        updates.append(progress)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return updates.count
    }

    var first: MigrationProgress? {
        lock.lock()
        defer { lock.unlock() }
        return updates.first
    }
}
