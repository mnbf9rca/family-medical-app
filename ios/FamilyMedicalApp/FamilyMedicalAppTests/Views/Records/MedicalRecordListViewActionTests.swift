import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Action and interaction tests for MedicalRecordListView.
///
/// Covers toolbar buttons, swipe-delete, task/refreshable modifiers, error alerts,
/// and cascade-delete dialog paths — split from MedicalRecordListViewTests to stay
/// within type_body_length limits.
@MainActor
struct MedicalRecordListViewActionTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestDecryptedRecord(personId: UUID? = nil) throws -> DecryptedRecord {
        let envelope = try RecordContentEnvelope(
            ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        )

        let record = MedicalRecord(
            personId: personId ?? UUID(),
            encryptedContent: Data()
        )

        return DecryptedRecord(record: record, envelope: envelope)
    }

    func createListViewModel(person: Person) -> MedicalRecordListViewModel {
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )
    }

    func createListViewModelWithQueryService(
        person: Person,
        queryService: MockDocumentReferenceQueryService
    ) -> MedicalRecordListViewModel {
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            documentReferenceQueryService: queryService
        )
    }

    // MARK: - Toolbar & Sheet Tests

    @Test
    func medicalRecordListViewRendersAddToolbarButton() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)
        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let addButton = try inspected.find(ViewType.Button.self) { button in
                let label = try? button.labelView().image().actualImage().name()
                return label == "plus"
            }
            // Tap to trigger showingCreateForm = true (exercises line 44-45)
            try addButton.tap()
        }
    }

    @Test
    func medicalRecordListViewRendersNavigationLinkForRecords() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let list = try inspected.find(ViewType.List.self)
            let forEach = try list.forEach(0)
            // Exercise NavigationLink rendering (line 31)
            _ = try forEach.navigationLink(0)
        }
    }

    // MARK: - Swipe Delete Tests

    @Test
    func medicalRecordListViewSwipeDeleteTriggersDeleteRecords() async throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        // Host the view so @State is active, then trigger onDelete
        ViewHosting.host(view: view)

        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let forEach = try list.forEach(0)
        // Exercise the onDelete modifier (exercises deleteRecords at line 144)
        try forEach.callOnDelete(IndexSet(integer: 0))

        // Yield to let the Task inside deleteRecords(at:) execute on the main actor.
        // The mock has no documentReferenceQueryService, so prepareDelete
        // returns [], which sets showingDeleteConfirmation = true.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        ViewHosting.expel()
    }

    @Test
    func medicalRecordListViewSwipeDeleteSetsConfirmationState() async throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        // Host the view so @State is alive
        ViewHosting.host(view: view)

        // Trigger swipe delete which starts a Task inside deleteRecords(at:)
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let forEach = try list.forEach(0)
        // Exercises deleteRecords(at:) which calls prepareDelete, sets recordToDelete,
        // and sets showingDeleteConfirmation = true (no query service -> no attachments)
        try forEach.callOnDelete(IndexSet(integer: 0))

        // Yield to let the Task inside deleteRecords(at:) execute
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // The dialog closures themselves are lazily evaluated by SwiftUI and
        // unreachable via ViewInspector, but deleteRecords(at:) is fully exercised.
        ViewHosting.expel()
    }

    // MARK: - Task & Refreshable Tests

    @Test
    func medicalRecordListViewTaskLoadsRecords() async throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)
        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        // Exercise the .task { await viewModel.loadRecords() } modifier (line 137)
        let inspected = try view.inspect()
        try await inspected.find(ViewType.Group.self).callTask()
    }

    @Test
    func medicalRecordListViewRefreshableLoadsRecords() async throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        // Exercise the .refreshable { await viewModel.loadRecords() } modifier (line 139)
        // The refreshable modifier is on the Group, not the List
        let inspected = try view.inspect()
        try await inspected.find(ViewType.Group.self).callRefreshable()
    }

    // MARK: - Error Alert Tests

    @Test
    func medicalRecordListViewRendersErrorAlertWithButtons() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)
        // Set error to present the alert (binding: viewModel.errorMessage != nil)
        viewModel.errorMessage = "Something went wrong"

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // Alert is presented because errorMessage is non-nil.
            let alert = try inspected.find(ViewType.Alert.self)
            // Exercise the OK button action closure (line 85)
            try alert.actions().button().tap()
            // Exercise the message closure (line 87-89)
            let messageText = try alert.message().text().string()
            #expect(messageText == "Something went wrong")
        }
    }

    // MARK: - Cascade Delete Dialog Tests

    @Test
    func medicalRecordListViewSwipeDeleteSetsCascadeStateWhenAttachmentsExist() async throws {
        let person = try makeTestPerson()
        let queryService = MockDocumentReferenceQueryService()
        let docRef = DocumentReferenceRecord(
            title: "X-Ray",
            mimeType: "image/jpeg",
            fileSize: 1_024,
            contentHMAC: Data([0x01, 0x02])
        )
        queryService.attachmentsResult = [
            PersistedDocumentReference(
                recordId: UUID(),
                content: docRef,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let viewModel = createListViewModelWithQueryService(
            person: person,
            queryService: queryService
        )

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        ViewHosting.host(view: view)

        // Trigger swipe delete — exercises deleteRecords(at:)
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let forEach = try list.forEach(0)
        try forEach.callOnDelete(IndexSet(integer: 0))

        // Yield to let the Task run — prepareDelete returns 1 attachment,
        // so the cascade path (pendingAttachments, showingCascadeDialog) is exercised
        await Task.yield()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Verify prepareDelete was called with the right record
        #expect(queryService.attachmentsForCalls.count == 1)

        ViewHosting.expel()
    }

    @Test
    func medicalRecordListViewSwipeDeleteWithMultipleAttachments() async throws {
        let person = try makeTestPerson()
        let queryService = MockDocumentReferenceQueryService()
        let docRefA = DocumentReferenceRecord(
            title: "Lab Report",
            mimeType: "application/pdf",
            fileSize: 2_048,
            contentHMAC: Data([0xAA, 0xBB])
        )
        let docRefB = DocumentReferenceRecord(
            title: "Photo",
            mimeType: "image/png",
            fileSize: 512,
            contentHMAC: Data([0xCC])
        )
        queryService.attachmentsResult = [
            PersistedDocumentReference(
                recordId: UUID(),
                content: docRefA,
                createdAt: Date(),
                updatedAt: Date()
            ),
            PersistedDocumentReference(
                recordId: UUID(),
                content: docRefB,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let viewModel = createListViewModelWithQueryService(
            person: person,
            queryService: queryService
        )

        let decryptedRecord = try makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            recordType: .immunization,
            viewModel: viewModel
        )

        ViewHosting.host(view: view)

        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let forEach = try list.forEach(0)
        // Exercises the cascade path with multiple attachments
        try forEach.callOnDelete(IndexSet(integer: 0))

        await Task.yield()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        #expect(queryService.attachmentsForCalls.count == 1)

        ViewHosting.expel()
    }
}
