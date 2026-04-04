import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("PersonBackup Tests")
struct PersonBackupTests {
    @Test("PersonBackup converts from Person model")
    func personBackupConversion() throws {
        let person = try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["child", "dependent"],
            notes: "Test notes"
        )

        let backup = PersonBackup(from: person)

        #expect(backup.id == person.id)
        #expect(backup.name == person.name)
        #expect(backup.labels == person.labels)
    }

    @Test("PersonBackup converts back to Person model")
    func personBackupToPerson() throws {
        let backup = PersonBackup(
            id: UUID(),
            name: "Test",
            dateOfBirth: Date(),
            labels: ["spouse"],
            notes: "Notes",
            createdAt: Date(),
            updatedAt: Date()
        )

        let person = try backup.toPerson()

        #expect(person.id == backup.id)
        #expect(person.name == backup.name)
    }

    @Test("PersonBackup round-trips through JSON")
    func personBackupRoundTrip() throws {
        let original = PersonBackup(
            id: UUID(),
            name: "John Doe",
            dateOfBirth: Date(timeIntervalSince1970: 1_000_000),
            labels: ["child", "dependent"],
            notes: "Some notes",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersonBackup.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.labels == original.labels)
    }
}

@Suite("MedicalRecordBackup Tests")
struct MedicalRecordBackupTests {
    @Test("MedicalRecordBackup direct initialization works")
    func medicalRecordBackupInit() throws {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let contentJSON = try JSONEncoder().encode(immunization)
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            recordType: "immunization",
            schemaVersion: 1,
            contentJSON: contentJSON,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        #expect(backup.recordType == "immunization")
        #expect(backup.schemaVersion == 1)
    }

    @Test("MedicalRecordBackup toEnvelope works")
    func medicalRecordBackupToEnvelope() throws {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let contentJSON = try JSONEncoder().encode(immunization)
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            recordType: "immunization",
            schemaVersion: 1,
            contentJSON: contentJSON,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        let envelope = try backup.toEnvelope()

        #expect(envelope.recordType == .immunization)
        #expect(envelope.schemaVersion == 1)
    }

    @Test("MedicalRecordBackup from record and envelope")
    func medicalRecordBackupFromRecordAndEnvelope() throws {
        let personId = UUID()
        let record = MedicalRecord(
            id: UUID(),
            personId: personId,
            encryptedContent: Data(),
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)

        let backup = MedicalRecordBackup(from: record, envelope: envelope)

        #expect(backup.id == record.id)
        #expect(backup.personId == personId)
        #expect(backup.recordType == "immunization")
        #expect(backup.schemaVersion == 1)
    }
}

@Suite("AttachmentBackup Tests")
struct AttachmentBackupTests {
    @Test("AttachmentBackup encodes content as base64")
    func attachmentBackupBase64() {
        let content = Data("Test file content".utf8)
        let thumbnail = Data("Thumbnail".utf8)

        let backup = AttachmentBackup(
            id: UUID(),
            personId: UUID(),
            linkedRecordIds: [],
            fileName: "test.txt",
            mimeType: "text/plain",
            content: content,
            thumbnail: thumbnail,
            uploadedAt: Date()
        )

        #expect(backup.contentData == content)
        #expect(backup.thumbnailData == thumbnail)
    }

    @Test("AttachmentBackup handles nil thumbnail")
    func attachmentBackupNilThumbnail() {
        let backup = AttachmentBackup(
            id: UUID(),
            personId: UUID(),
            linkedRecordIds: [],
            fileName: "test.txt",
            mimeType: "text/plain",
            content: Data("content".utf8),
            thumbnail: nil,
            uploadedAt: Date()
        )

        #expect(backup.thumbnailData == nil)
    }
}
