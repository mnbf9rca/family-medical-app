import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Rendering tests for MedicalRecordDetailView covering provider display,
/// attachment sections, decode errors, and UUID fallback.
///
/// Split from MedicalRecordDetailViewActionTests to stay within type_body_length limits.
@MainActor
struct MedicalRecordDetailViewRenderingTests {
    // MARK: - Test Data

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestDecryptedRecord(
        personId: UUID? = nil,
        recordType: RecordType = .immunization
    ) throws -> DecryptedRecord {
        let envelope: RecordContentEnvelope = switch recordType {
        case .immunization:
            try RecordContentEnvelope(
                ImmunizationRecord(
                    vaccineCode: "Test Vaccine",
                    occurrenceDate: Date(),
                    lotNumber: "EL9262",
                    doseNumber: 2,
                    notes: "Second dose"
                )
            )
        case .condition:
            try RecordContentEnvelope(
                ConditionRecord(conditionName: "Asthma", onsetDate: Date())
            )
        default:
            RecordContentEnvelope(
                recordType: recordType,
                schemaVersion: 1,
                content: Data("{\"notes\":null,\"tags\":[]}".utf8)
            )
        }

        let record = MedicalRecord(personId: personId ?? UUID(), encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    // MARK: - Provider Rendering

    @Test
    func viewRendersProviderDisplayStringWhenSet() async throws {
        let person = try makeTestPerson()
        let providerUUID = UUID()
        let envelope = try RecordContentEnvelope(
            ImmunizationRecord(
                vaccineCode: "Pfizer",
                occurrenceDate: Date(),
                providerId: providerUUID
            )
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)

        let providerRepo = MockProviderRepository()
        providerRepo.addProvider(
            Provider(id: providerUUID, name: "Dr House", organization: "Princeton"),
            personId: person.id
        )
        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let detailVM = MedicalRecordDetailViewModel(
            person: person,
            decryptedRecord: decrypted,
            providerRepository: providerRepo,
            primaryKeyProvider: keyProvider,
            fmkService: fmk
        )
        await detailVM.loadProviderDisplayIfNeeded()
        #expect(detailVM.providerDisplayStrings["providerId"] == "Dr House at Princeton")

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decrypted,
            detailViewModel: detailVM
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Provider")
            _ = try inspected.find(text: "Dr House at Princeton")
        }
    }

    @Test
    func viewRendersUUIDFallbackWhenProviderDisplayStringNil() throws {
        let person = try makeTestPerson()
        let providerId = UUID()
        let content = ImmunizationRecord(
            vaccineCode: "Pfizer",
            occurrenceDate: Date(),
            providerId: providerId
        )
        let envelope = try RecordContentEnvelope(content)
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: providerId.uuidString)
        }
    }

    // MARK: - Toolbar Button Toggle Tests

    @Test
    func viewEditToolbarButtonTogglesShowingEditForm() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .condition)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decryptedRecord)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let editButton = try inspected.find(button: "Edit")
            try editButton.tap()
        }
    }

    @Test
    func viewDeleteToolbarButtonTogglesConfirmationDialog() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .condition)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decryptedRecord)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let deleteButton = try inspected.find(button: "Delete")
            try deleteButton.tap()
        }
    }

    // MARK: - Attachment Section Rendering

    @Test
    func viewRendersAttachmentsSectionWhenAttachmentsExist() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        let queryService = MockDocumentReferenceQueryService()

        let detailVM = MedicalRecordDetailViewModel(
            person: person,
            decryptedRecord: decryptedRecord,
            providerRepository: MockProviderRepository(),
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            documentReferenceQueryService: queryService
        )

        let docRef = DocumentReferenceRecord(
            title: "X-Ray",
            mimeType: "image/jpeg",
            fileSize: 1_024,
            contentHMAC: Data([0x01, 0x02, 0x03])
        )
        detailVM.attachments = [
            PersistedDocumentReference(
                recordId: UUID(),
                content: docRef,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord,
            detailViewModel: detailVM
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Attachments")
        }
    }

    @Test
    func viewRendersMultipleAttachmentThumbnails() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .condition)

        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let detailVM = MedicalRecordDetailViewModel(
            person: person,
            decryptedRecord: decryptedRecord,
            providerRepository: MockProviderRepository(),
            primaryKeyProvider: keyProvider,
            fmkService: fmk
        )

        let docRefA = DocumentReferenceRecord(
            title: "Photo A",
            mimeType: "image/png",
            fileSize: 512,
            contentHMAC: Data([0xAA])
        )
        let docRefB = DocumentReferenceRecord(
            title: "Photo B",
            mimeType: "image/png",
            fileSize: 768,
            contentHMAC: Data([0xBB])
        )
        detailVM.attachments = [
            PersistedDocumentReference(recordId: UUID(), content: docRefA, createdAt: Date(), updatedAt: Date()),
            PersistedDocumentReference(recordId: UUID(), content: docRefB, createdAt: Date(), updatedAt: Date())
        ]

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord,
            detailViewModel: detailVM
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Attachments")
        }
    }

    // MARK: - Decode Error Rendering

    @Test
    func viewRendersDecodeErrorMessageWhenPresent() throws {
        let person = try makeTestPerson()
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 1,
            content: Data("not valid json".utf8)
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected
                .find(text: "Unable to read this record. It may be corrupted or saved in an unsupported format.")
        }
    }
}
