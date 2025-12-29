import Foundation
import Testing
@testable import FamilyMedicalApp

struct MedicalRecordRepositoryTests {
    // MARK: - Test Fixtures

    func makeRepository() -> MedicalRecordRepository {
        let stack = MockCoreDataStack()
        return MedicalRecordRepository(coreDataStack: stack)
    }

    func makeTestRecord(
        id: UUID = UUID(),
        personId: UUID = UUID(),
        version: Int = 1,
        createdAt: Date = Date(timeIntervalSince1970: 1_000_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_000_000_000),
        encryptedContent: Data = Data("encrypted record content".utf8),
        previousVersionId: UUID? = nil
    ) -> MedicalRecord {
        MedicalRecord(
            id: id,
            personId: personId,
            encryptedContent: encryptedContent,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            previousVersionId: previousVersionId
        )
    }

    // MARK: - Save Tests

    @Test
    func save_newRecord_storesInCoreData() async throws {
        let repo = makeRepository()
        let record = makeTestRecord()

        try await repo.save(record)

        // Verify record was saved
        let fetched = try await repo.fetch(id: record.id)
        #expect(fetched != nil)
        #expect(fetched?.id == record.id)
        #expect(fetched?.personId == record.personId)
        #expect(fetched?.encryptedContent == record.encryptedContent)
    }

    @Test
    func save_existingRecord_updates() async throws {
        let repo = makeRepository()
        let recordId = UUID()
        let personId = UUID()

        // Save initially
        let record = makeTestRecord(id: recordId, personId: personId, version: 1)
        try await repo.save(record)

        // Update the record (create new instance with same ID)
        let updated = makeTestRecord(
            id: recordId,
            personId: personId,
            version: 2,
            updatedAt: Date(timeIntervalSince1970: 2_000_000_000),
            encryptedContent: Data("updated encrypted content".utf8)
        )

        try await repo.save(updated)

        // Verify update
        let fetched = try await repo.fetch(id: recordId)
        #expect(fetched?.version == 2)
        #expect(fetched?.updatedAt == updated.updatedAt)
        #expect(fetched?.encryptedContent == updated.encryptedContent)
    }

    @Test
    func save_existingRecord_preservesOriginalCreatedAt() async throws {
        let repo = makeRepository()
        let recordId = UUID()
        let personId = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000_000_000)

        // Save initially
        let record = makeTestRecord(
            id: recordId,
            personId: personId,
            version: 1,
            createdAt: originalCreatedAt
        )
        try await repo.save(record)

        // Update the record with a different createdAt value
        let differentCreatedAt = Date(timeIntervalSince1970: 1_500_000_000)
        let updated = makeTestRecord(
            id: recordId,
            personId: personId,
            version: 2,
            createdAt: differentCreatedAt, // Try to change createdAt
            updatedAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        try await repo.save(updated)

        // Verify createdAt was preserved from original, not overwritten
        let fetched = try await repo.fetch(id: recordId)
        #expect(fetched?.createdAt == originalCreatedAt)
        #expect(fetched?.createdAt != differentCreatedAt)
    }

    @Test
    func save_recordWithPreviousVersion_storesVersionId() async throws {
        let repo = makeRepository()
        let previousId = UUID()

        let record = makeTestRecord(
            version: 2,
            previousVersionId: previousId
        )

        try await repo.save(record)

        let fetched = try await repo.fetch(id: record.id)
        #expect(fetched?.previousVersionId == previousId)
        #expect(fetched?.version == 2)
    }

    // MARK: - Fetch Tests

    @Test
    func fetch_existingRecord_returnsRecord() async throws {
        let repo = makeRepository()
        let record = makeTestRecord()

        try await repo.save(record)
        let fetched = try await repo.fetch(id: record.id)

        #expect(fetched != nil)
        #expect(fetched?.id == record.id)
        #expect(fetched?.personId == record.personId)
        #expect(fetched?.createdAt == record.createdAt)
        #expect(fetched?.updatedAt == record.updatedAt)
        #expect(fetched?.version == record.version)
        #expect(fetched?.encryptedContent == record.encryptedContent)
    }

    @Test
    func fetch_nonExistentRecord_returnsNil() async throws {
        let repo = makeRepository()

        let result = try await repo.fetch(id: UUID())

        #expect(result == nil)
    }

    // MARK: - FetchForPerson Tests

    @Test
    func fetchForPerson_multipleRecords_returnsAll() async throws {
        let repo = makeRepository()
        let personId = UUID()

        let record1 = makeTestRecord(personId: personId)
        let record2 = makeTestRecord(personId: personId)
        let record3 = makeTestRecord(personId: personId)

        try await repo.save(record1)
        try await repo.save(record2)
        try await repo.save(record3)

        let results = try await repo.fetchForPerson(personId: personId)

        #expect(results.count == 3)
        #expect(results.contains { $0.id == record1.id })
        #expect(results.contains { $0.id == record2.id })
        #expect(results.contains { $0.id == record3.id })
    }

    @Test
    func fetchForPerson_noRecords_returnsEmptyArray() async throws {
        let repo = makeRepository()

        let results = try await repo.fetchForPerson(personId: UUID())

        #expect(results.isEmpty)
    }

    @Test
    func fetchForPerson_mixedPersons_returnsOnlyMatchingPerson() async throws {
        let repo = makeRepository()
        let personId1 = UUID()
        let personId2 = UUID()

        let record1 = makeTestRecord(personId: personId1)
        let record2 = makeTestRecord(personId: personId2)
        let record3 = makeTestRecord(personId: personId1)

        try await repo.save(record1)
        try await repo.save(record2)
        try await repo.save(record3)

        let results = try await repo.fetchForPerson(personId: personId1)

        #expect(results.count == 2)
        #expect(results.contains { $0.id == record1.id })
        #expect(results.contains { $0.id == record3.id })
        #expect(!results.contains { $0.id == record2.id })
    }

    @Test
    func fetchForPerson_sortedByCreatedAtDescending() async throws {
        let repo = makeRepository()
        let personId = UUID()

        let record1 = makeTestRecord(
            personId: personId,
            createdAt: Date(timeIntervalSince1970: 1_000_000_000)
        )

        let record2 = makeTestRecord(
            personId: personId,
            createdAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        let record3 = makeTestRecord(
            personId: personId,
            createdAt: Date(timeIntervalSince1970: 3_000_000_000)
        )

        // Save in random order
        try await repo.save(record2)
        try await repo.save(record1)
        try await repo.save(record3)

        let results = try await repo.fetchForPerson(personId: personId)

        // Should be sorted newest first
        #expect(results[0].id == record3.id)
        #expect(results[1].id == record2.id)
        #expect(results[2].id == record1.id)
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingRecord_removes() async throws {
        let repo = makeRepository()
        let record = makeTestRecord()

        try await repo.save(record)
        #expect(try await repo.exists(id: record.id))

        try await repo.delete(id: record.id)

        let exists = try await repo.exists(id: record.id)
        #expect(!exists)
    }

    @Test
    func delete_nonExistentRecord_throwsError() async throws {
        let repo = makeRepository()

        await #expect(throws: RepositoryError.self) {
            try await repo.delete(id: UUID())
        }
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingRecord_returnsTrue() async throws {
        let repo = makeRepository()
        let record = makeTestRecord()

        try await repo.save(record)

        let exists = try await repo.exists(id: record.id)
        #expect(exists)
    }

    @Test
    func exists_nonExistentRecord_returnsFalse() async throws {
        let repo = makeRepository()

        let exists = try await repo.exists(id: UUID())
        #expect(!exists)
    }

    // MARK: - Version Tracking Tests

    @Test
    func save_multipleVersions_tracksHistory() async throws {
        let repo = makeRepository()
        let personId = UUID()

        // Version 1
        let v1 = makeTestRecord(id: UUID(), personId: personId, version: 1)
        try await repo.save(v1)

        // Version 2 (references v1)
        var v2 = makeTestRecord(id: UUID(), personId: personId, version: 2)
        v2.previousVersionId = v1.id
        try await repo.save(v2)

        // Fetch both
        let fetched1 = try await repo.fetch(id: v1.id)
        let fetched2 = try await repo.fetch(id: v2.id)

        #expect(fetched1?.version == 1)
        #expect(fetched1?.previousVersionId == nil)

        #expect(fetched2?.version == 2)
        #expect(fetched2?.previousVersionId == v1.id)
    }
}
