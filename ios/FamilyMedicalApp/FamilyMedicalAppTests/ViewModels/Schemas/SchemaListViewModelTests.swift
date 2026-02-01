import CryptoKit
import Dependencies
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct SchemaListViewModelTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func createTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func createTestSchema(
        id: String,
        displayName: String,
        isBuiltIn: Bool = false
    ) -> RecordSchema {
        RecordSchema(
            unsafeId: id,
            displayName: displayName,
            iconSystemName: isBuiltIn ? "syringe" : "doc.text",
            fields: [],
            isBuiltIn: isBuiltIn,
            description: nil
        )
    }

    func createTestRecord(person: Person, schemaId: String) throws -> MedicalRecord {
        let content = RecordContent(schemaId: schemaId)
        let service = MockRecordContentService()
        let encryptedData = try service.encrypt(content, using: testFMK)

        return MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedData
        )
    }

    // MARK: - Load Schemas Tests

    @Test
    func loadSchemasSucceedsWithMixedSchemaTypes() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let vaccineSchema = createTestSchema(id: "vaccine", displayName: "Vaccine", isBuiltIn: true)
        let customSchema = createTestSchema(id: "custom-123", displayName: "Custom", isBuiltIn: false)
        mockSchemaRepo.addSchema(vaccineSchema, forPerson: person.id)
        mockSchemaRepo.addSchema(customSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.count == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadSchemasSortsBuiltInFirst() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        // Add in reverse order to verify sorting
        let customSchema = createTestSchema(id: "custom-123", displayName: "Aardvark Custom", isBuiltIn: false)
        let vaccineSchema = createTestSchema(id: "vaccine", displayName: "Zebra Vaccine", isBuiltIn: true)
        mockSchemaRepo.addSchema(customSchema, forPerson: person.id)
        mockSchemaRepo.addSchema(vaccineSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.count == 2)
        // Built-in should come first regardless of name
        #expect(viewModel.schemas[0].isBuiltIn == true)
        #expect(viewModel.schemas[1].isBuiltIn == false)
    }

    @Test
    func loadSchemasSortsAlphabeticallyWithinGroups() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let zSchema = createTestSchema(id: "vaccine", displayName: "Vaccine Z", isBuiltIn: true)
        let aSchema = createTestSchema(id: "condition", displayName: "Condition A", isBuiltIn: true)
        mockSchemaRepo.addSchema(zSchema, forPerson: person.id)
        mockSchemaRepo.addSchema(aSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.count == 2)
        // Should be alphabetical: Condition A, then Vaccine Z
        #expect(viewModel.schemas[0].displayName == "Condition A")
        #expect(viewModel.schemas[1].displayName == "Vaccine Z")
    }

    @Test
    func loadSchemasIncludesRecordCounts() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let vaccineSchema = createTestSchema(id: "vaccine", displayName: "Vaccine", isBuiltIn: true)
        mockSchemaRepo.addSchema(vaccineSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Add 3 vaccine records
        for _ in 0 ..< 3 {
            let record = try createTestRecord(person: person, schemaId: "vaccine")
            mockRecordRepo.addRecord(record)
            mockContentService.setContent(
                RecordContent(schemaId: "vaccine"),
                for: record.encryptedContent
            )
        }

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.recordCounts["vaccine"] == 3)
    }

    @Test
    func loadSchemasReturnsEmptyWhenNoSchemas() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.isEmpty)
        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadSchemasSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil)
        let mockFMKService = MockFamilyMemberKeyService()

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to load") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadSchemasSetsErrorWhenFetchAllFails() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        mockSchemaRepo.shouldFailFetchAll = true

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        #expect(viewModel.schemas.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }
}

// MARK: - Create New Schema Tests

extension SchemaListViewModelTests {
    @Test
    func createNewSchemaTemplateReturnsSchemaWithValidStructure() throws {
        let person = try createTestPerson()

        // Use a fixed UUID to test deterministic behavior
        let fixedUUID = try #require(UUID(uuidString: "ABCD1234-0000-0000-0000-000000000000"))
        let viewModel = withDependencies {
            $0.uuid = .constant(fixedUUID)
        } operation: {
            SchemaListViewModel(
                person: person,
                customSchemaRepository: MockCustomSchemaRepository(),
                medicalRecordRepository: MockMedicalRecordRepository(),
                recordContentService: MockRecordContentService(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        let schema = viewModel.createNewSchemaTemplate()

        #expect(schema.id == "custom-abcd1234")
        #expect(schema.isBuiltIn == false)
        #expect(schema.displayName == "New Record Type")
        #expect(schema.iconSystemName == "doc.text")
        #expect(schema.fields.isEmpty)
    }

    @Test
    func createNewSchemaTemplateGeneratesUniqueIdsWithDifferentUUIDs() throws {
        let person = try createTestPerson()

        // Create two ViewModels with different UUID generators
        let uuid1 = try #require(UUID(uuidString: "11111111-0000-0000-0000-000000000000"))
        let uuid2 = try #require(UUID(uuidString: "22222222-0000-0000-0000-000000000000"))

        let viewModel1 = withDependencies {
            $0.uuid = .constant(uuid1)
        } operation: {
            SchemaListViewModel(
                person: person,
                customSchemaRepository: MockCustomSchemaRepository(),
                medicalRecordRepository: MockMedicalRecordRepository(),
                recordContentService: MockRecordContentService(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        let viewModel2 = withDependencies {
            $0.uuid = .constant(uuid2)
        } operation: {
            SchemaListViewModel(
                person: person,
                customSchemaRepository: MockCustomSchemaRepository(),
                medicalRecordRepository: MockMedicalRecordRepository(),
                recordContentService: MockRecordContentService(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        let schema1 = viewModel1.createNewSchemaTemplate()
        let schema2 = viewModel2.createNewSchemaTemplate()

        #expect(schema1.id == "custom-11111111")
        #expect(schema2.id == "custom-22222222")
        #expect(schema1.id != schema2.id)
    }
}

// MARK: - Delete Schema Tests

extension SchemaListViewModelTests {
    @Test
    func deleteSchemaSucceedsForCustomSchema() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let customSchema = createTestSchema(id: "custom-123", displayName: "Custom", isBuiltIn: false)
        mockSchemaRepo.addSchema(customSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        // Load schemas first
        await viewModel.loadSchemas()
        #expect(viewModel.schemas.count == 1)

        // Delete
        let success = await viewModel.deleteSchema(schemaId: "custom-123")

        #expect(success == true)
        #expect(viewModel.schemas.isEmpty)
        #expect(viewModel.recordCounts["custom-123"] == nil)
        #expect(mockSchemaRepo.deleteCallCount == 1)
    }

    @Test
    func deleteSchemaFailsForBuiltInSchema() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let vaccineSchema = createTestSchema(id: "vaccine", displayName: "Vaccine", isBuiltIn: true)
        mockSchemaRepo.addSchema(vaccineSchema, forPerson: person.id)

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        // Load schemas first
        await viewModel.loadSchemas()

        // Try to delete built-in
        let success = await viewModel.deleteSchema(schemaId: "vaccine")

        #expect(success == false)
        #expect(viewModel.schemas.count == 1) // Still there
        #expect(viewModel.errorMessage?.contains("Built-in") == true)
        #expect(mockSchemaRepo.deleteCallCount == 0) // Never called
    }

    @Test
    func deleteSchemaHandlesRepositoryFailure() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let customSchema = createTestSchema(id: "custom-123", displayName: "Custom", isBuiltIn: false)
        mockSchemaRepo.addSchema(customSchema, forPerson: person.id)
        mockSchemaRepo.shouldFailDelete = true

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadSchemas()

        let success = await viewModel.deleteSchema(schemaId: "custom-123")

        #expect(success == false)
        #expect(viewModel.errorMessage?.contains("Unable to delete") == true)
    }
}

// MARK: - Loading State Tests

extension SchemaListViewModelTests {
    @Test
    func loadSchemasUpdatesLoadingState() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        #expect(viewModel.isLoading == false)

        await viewModel.loadSchemas()

        #expect(viewModel.isLoading == false) // Should be false after completion
    }

    @Test
    func loadSchemasClearsErrorOnRetry() async throws {
        let person = try createTestPerson()

        let mockSchemaRepo = MockCustomSchemaRepository()
        mockSchemaRepo.shouldFailFetchAll = true

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaListViewModel(
            person: person,
            customSchemaRepository: mockSchemaRepo,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        // First load fails
        await viewModel.loadSchemas()
        #expect(viewModel.errorMessage != nil)

        // Fix the mock and retry
        mockSchemaRepo.shouldFailFetchAll = false
        await viewModel.loadSchemas()
        #expect(viewModel.errorMessage == nil)
    }
}
