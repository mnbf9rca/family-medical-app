import CoreData
import Testing
@testable import FamilyMedicalApp

struct CoreDataStackTests {
    // MARK: - Initialization Tests

    @Test
    func init_inMemory_loadsSuccessfully() {
        let stack = CoreDataStack(inMemory: true)

        // viewContext should be initialized
        #expect(stack.viewContext.persistentStoreCoordinator != nil)
    }

    @Test
    func viewContext_hasAutomaticMerge() {
        let stack = CoreDataStack(inMemory: true)

        #expect(stack.viewContext.automaticallyMergesChangesFromParent == true)
    }

    @Test
    func viewContext_hasMergePolicy() {
        let stack = CoreDataStack(inMemory: true)

        let policy = stack.viewContext.mergePolicy as? NSMergePolicy
        #expect(policy == NSMergePolicy.mergeByPropertyObjectTrump)
    }

    // MARK: - Background Context Tests

    @Test
    func newBackgroundContext_returnsContext() {
        let stack = CoreDataStack(inMemory: true)

        let context = stack.newBackgroundContext()

        // Should return different instance from viewContext
        #expect(context !== stack.viewContext)
    }

    @Test
    func newBackgroundContext_hasMergePolicy() {
        let stack = CoreDataStack(inMemory: true)

        let context = stack.newBackgroundContext()
        let policy = context.mergePolicy as? NSMergePolicy

        #expect(policy == NSMergePolicy.mergeByPropertyObjectTrump)
    }

    // MARK: - Background Task Tests

    @Test
    func performBackgroundTask_executesBlock() async throws {
        let stack = CoreDataStack(inMemory: true)

        let result = try await stack.performBackgroundTask { _ in
            42
        }

        #expect(result == 42)
    }

    @Test
    func performBackgroundTask_throwsError() async throws {
        let stack = CoreDataStack(inMemory: true)

        await #expect(throws: TestError.self) {
            try await stack.performBackgroundTask { _ in
                throw TestError.mockError
            }
        }
    }

    @Test
    func performBackgroundTask_providesBackgroundContext() async throws {
        let stack = CoreDataStack(inMemory: true)

        try await stack.performBackgroundTask { context in
            // Verify it's not the view context
            #expect(context !== stack.viewContext)
        }
    }

    // MARK: - Core Data Model Tests

    @Test
    func coreDataModel_hasPersonEntity() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel

        let personEntity = model?.entitiesByName["PersonEntity"]
        #expect(personEntity != nil)
    }

    @Test
    func coreDataModel_hasMedicalRecordEntity() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel

        let recordEntity = model?.entitiesByName["MedicalRecordEntity"]
        #expect(recordEntity != nil)
    }

    @Test
    func coreDataModel_hasAttachmentEntity() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel

        let attachmentEntity = model?.entitiesByName["AttachmentEntity"]
        #expect(attachmentEntity != nil)
    }

    @Test
    func coreDataModel_hasRecordAttachmentEntity() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel

        let joinEntity = model?.entitiesByName["RecordAttachmentEntity"]
        #expect(joinEntity != nil)
    }

    // MARK: - Entity Attribute Tests

    @Test
    func personEntity_hasRequiredAttributes() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel
        let entity = model?.entitiesByName["PersonEntity"]

        let attributes = entity?.attributesByName
        #expect(attributes?["id"] != nil)
        #expect(attributes?["createdAt"] != nil)
        #expect(attributes?["updatedAt"] != nil)
        #expect(attributes?["encryptedData"] != nil)
    }

    @Test
    func medicalRecordEntity_hasRequiredAttributes() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel
        let entity = model?.entitiesByName["MedicalRecordEntity"]

        let attributes = entity?.attributesByName
        #expect(attributes?["id"] != nil)
        #expect(attributes?["personId"] != nil)
        #expect(attributes?["createdAt"] != nil)
        #expect(attributes?["updatedAt"] != nil)
        #expect(attributes?["version"] != nil)
        #expect(attributes?["previousVersionId"] != nil)
        #expect(attributes?["encryptedContent"] != nil)
    }

    @Test
    func attachmentEntity_hasRequiredAttributes() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel
        let entity = model?.entitiesByName["AttachmentEntity"]

        let attributes = entity?.attributesByName
        #expect(attributes?["id"] != nil)
        #expect(attributes?["uploadedAt"] != nil)
        #expect(attributes?["contentHMAC"] != nil)
        #expect(attributes?["encryptedSize"] != nil)
        #expect(attributes?["encryptedMetadata"] != nil)
    }

    @Test
    func recordAttachmentEntity_hasRequiredAttributes() {
        let stack = CoreDataStack(inMemory: true)
        let model = stack.viewContext.persistentStoreCoordinator?.managedObjectModel
        let entity = model?.entitiesByName["RecordAttachmentEntity"]

        let attributes = entity?.attributesByName
        #expect(attributes?["recordId"] != nil)
        #expect(attributes?["attachmentId"] != nil)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case mockError
}
