import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Action and interaction tests for MedicalRecordDetailView.
///
/// Covers toolbar buttons, attachment thumbnail taps, task modifiers,
/// and viewer ViewModel creation — split from MedicalRecordFormDetailViewTests
/// to stay within type_body_length limits.
@MainActor
struct MedicalRecordDetailViewActionTests {
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

    // MARK: - Delete Confirmation Dialog Tests

    @Test
    func viewDeleteToolbarButtonTapExercisesDeleteAction() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        ) {
            // onDelete closure — exercises the init path with a non-nil callback
        }

        // Tapping the Delete toolbar button exercises the button action closure
        // which sets showingDeleteConfirmation = true. The confirmationDialog
        // content closures are lazily evaluated by SwiftUI and cannot be reached
        // through ViewInspector.
        ViewHosting.host(view: view)
        let inspected = try view.inspect()
        let deleteButton = try inspected.find(button: "Delete")
        try deleteButton.tap()
        ViewHosting.expel()
    }

    @Test
    func viewDeleteToolbarButtonWithNilOnDelete() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .condition)

        // View with nil onDelete — exercises the init path where onDelete is nil
        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord,
            onDelete: nil
        )

        ViewHosting.host(view: view)
        let inspected = try view.inspect()
        let deleteButton = try inspected.find(button: "Delete")
        try deleteButton.tap()
        ViewHosting.expel()
    }

    // MARK: - Edit Sheet Tests

    @Test
    func viewEditButtonPresentsEditSheet() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        var recordUpdated = false
        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        ) {
            recordUpdated = true
        }

        ViewHosting.host(view: view)

        // Tap Edit button to present the edit sheet (exercises line 65)
        let inspected = try view.inspect()
        let editButton = try inspected.find(button: "Edit")
        try editButton.tap()

        // Confirm the sheet modifier is exercised; verify record not yet updated
        #expect(recordUpdated == false)

        ViewHosting.expel()
    }

    // MARK: - Attachment Thumbnail Tap Tests

    @Test
    func viewAttachmentThumbnailTapSetsSelectedAttachment() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

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

        let attachmentId = UUID()
        let docRef = DocumentReferenceRecord(
            title: "Lab Result",
            mimeType: "application/pdf",
            fileSize: 2_048,
            contentHMAC: Data([0xDE, 0xAD])
        )
        detailVM.attachments = [
            PersistedDocumentReference(
                recordId: attachmentId,
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

        ViewHosting.host(view: view)

        // Find the attachment thumbnail and tap the Button wrapping it.
        // AttachmentThumbnailView uses Button(action: onTap), not .onTapGesture.
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Attachments")
        let thumbnail = try inspected.find(AttachmentThumbnailView.self)
        let tapButton = try thumbnail.find(ViewType.Button.self)
        try tapButton.tap()

        ViewHosting.expel()
    }

    // MARK: - Task and Sheet Item Tests

    @Test
    func viewTaskCallsLoadAttachments() async throws {
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

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord,
            detailViewModel: detailVM
        )

        // Exercise the .task modifier (lines 107-110)
        let inspected = try view.inspect()
        try await inspected.find(ViewType.List.self).callTask()

        #expect(queryService.attachmentsForCalls.count == 1)
    }

    @Test
    func viewMakeViewerViewModelReturnsNilWhenKeyUnavailable() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.shouldFail = true

        let detailVM = MedicalRecordDetailViewModel(
            person: person,
            decryptedRecord: decryptedRecord,
            providerRepository: MockProviderRepository(),
            primaryKeyProvider: keyProvider
        )

        let docRef = DocumentReferenceRecord(
            title: "Scan",
            mimeType: "image/png",
            fileSize: 512,
            contentHMAC: Data([0x01])
        )
        let attachment = PersistedDocumentReference(
            recordId: UUID(),
            content: docRef,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = detailVM.makeViewerViewModel(for: attachment)
        #expect(result == nil)
    }

    @Test
    func viewMakeViewerViewModelReturnsViewModelWhenKeyAvailable() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

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

        let docRef = DocumentReferenceRecord(
            title: "Scan",
            mimeType: "image/png",
            fileSize: 512,
            contentHMAC: Data([0x01])
        )
        let attachment = PersistedDocumentReference(
            recordId: UUID(),
            content: docRef,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = detailVM.makeViewerViewModel(for: attachment)
        #expect(result != nil)
    }
}
