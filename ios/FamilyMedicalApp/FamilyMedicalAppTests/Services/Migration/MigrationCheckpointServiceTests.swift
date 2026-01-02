import CoreData
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Helper struct to avoid large tuple SwiftLint violation
private struct CheckpointTestMocks {
    let service: MigrationCheckpointService
    let coreDataStack: MockCoreDataStack
    let recordRepo: MockMedicalRecordRepository

    init() {
        self.coreDataStack = MockCoreDataStack()
        self.recordRepo = MockMedicalRecordRepository()
        self.service = MigrationCheckpointService(
            coreDataStack: coreDataStack,
            medicalRecordRepository: recordRepo
        )
    }
}

/// Tests for MigrationCheckpointService
struct MigrationCheckpointServiceTests {
    private func makeMocks() -> CheckpointTestMocks { CheckpointTestMocks() }

    private func makeTestRecord(personId: UUID = UUID()) -> MedicalRecord {
        MedicalRecord(personId: personId, encryptedContent: Data("test content".utf8))
    }

    // MARK: - Create Checkpoint Tests

    @Test("Creates checkpoint successfully")
    func createCheckpointSuccess() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )

        let hasCheckpoint = try await mocks.service.hasCheckpoint(migrationId: migrationId)
        #expect(hasCheckpoint)
    }

    @Test("Throws when checkpoint already exists")
    func createCheckpointDuplicate() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )

        await #expect(throws: RepositoryError.self) {
            try await mocks.service.createCheckpoint(
                migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
            )
        }
    }

    @Test("Creates checkpoint with multiple records")
    func createCheckpointMultipleRecords() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [
            makeTestRecord(personId: personId),
            makeTestRecord(personId: personId),
            makeTestRecord(personId: personId)
        ]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )

        let hasCheckpoint = try await mocks.service.hasCheckpoint(migrationId: migrationId)
        #expect(hasCheckpoint)
    }

    // MARK: - Restore Checkpoint Tests

    @Test("Restores checkpoint successfully")
    func restoreCheckpointSuccess() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let originalRecords = [makeTestRecord(personId: personId), makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: originalRecords
        )

        let restoredRecords = try await mocks.service.restoreCheckpoint(migrationId: migrationId)

        #expect(restoredRecords.count == 2)
        #expect(mocks.recordRepo.saveCallCount == 2)
    }

    @Test("Throws when checkpoint not found")
    func restoreCheckpointNotFound() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()

        await #expect(throws: RepositoryError.self) {
            _ = try await mocks.service.restoreCheckpoint(migrationId: migrationId)
        }
    }

    @Test("Restored records match original")
    func restoreCheckpointMatchesOriginal() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let originalRecord = makeTestRecord(personId: personId)

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: [originalRecord]
        )

        let restoredRecords = try await mocks.service.restoreCheckpoint(migrationId: migrationId)

        #expect(restoredRecords.count == 1)
        #expect(restoredRecords.first?.id == originalRecord.id)
        #expect(restoredRecords.first?.personId == originalRecord.personId)
        #expect(restoredRecords.first?.encryptedContent == originalRecord.encryptedContent)
    }

    // MARK: - Delete Checkpoint Tests

    @Test("Deletes checkpoint successfully")
    func deleteCheckpointSuccess() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )

        try await mocks.service.deleteCheckpoint(migrationId: migrationId)

        let hasCheckpoint = try await mocks.service.hasCheckpoint(migrationId: migrationId)
        #expect(!hasCheckpoint)
    }

    @Test("Delete non-existent checkpoint does not throw")
    func deleteCheckpointNotFound() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()

        try await mocks.service.deleteCheckpoint(migrationId: migrationId)
    }

    // MARK: - Has Checkpoint Tests

    @Test("Returns false when no checkpoint exists")
    func hasCheckpointFalse() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()

        let hasCheckpoint = try await mocks.service.hasCheckpoint(migrationId: migrationId)
        #expect(!hasCheckpoint)
    }

    @Test("Returns true when checkpoint exists")
    func hasCheckpointTrue() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )

        let hasCheckpoint = try await mocks.service.hasCheckpoint(migrationId: migrationId)
        #expect(hasCheckpoint)
    }

    // MARK: - Integration Tests

    @Test("Full checkpoint lifecycle: create, restore, delete")
    func fullLifecycle() async throws {
        let mocks = makeMocks()
        let migrationId = UUID()
        let personId = UUID()
        let records = [makeTestRecord(personId: personId)]

        try await mocks.service.createCheckpoint(
            migrationId: migrationId, personId: personId, schemaId: "test-schema", records: records
        )
        #expect(try await mocks.service.hasCheckpoint(migrationId: migrationId))

        let restored = try await mocks.service.restoreCheckpoint(migrationId: migrationId)
        #expect(restored.count == 1)

        try await mocks.service.deleteCheckpoint(migrationId: migrationId)
        #expect(try await !mocks.service.hasCheckpoint(migrationId: migrationId))
    }

    @Test("Multiple independent checkpoints")
    func multipleCheckpoints() async throws {
        let mocks = makeMocks()
        let migrationId1 = UUID()
        let migrationId2 = UUID()
        let personId = UUID()

        try await mocks.service.createCheckpoint(
            migrationId: migrationId1,
            personId: personId,
            schemaId: "schema1",
            records: [makeTestRecord(personId: personId)]
        )

        try await mocks.service.createCheckpoint(
            migrationId: migrationId2,
            personId: personId,
            schemaId: "schema2",
            records: [makeTestRecord(personId: personId), makeTestRecord(personId: personId)]
        )

        #expect(try await mocks.service.hasCheckpoint(migrationId: migrationId1))
        #expect(try await mocks.service.hasCheckpoint(migrationId: migrationId2))

        try await mocks.service.deleteCheckpoint(migrationId: migrationId1)
        #expect(try await !mocks.service.hasCheckpoint(migrationId: migrationId1))
        #expect(try await mocks.service.hasCheckpoint(migrationId: migrationId2))
    }
}
