import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct DemoDataSeederTests {
    // MARK: - Seed Demo Data Tests

    @Test
    func seedDemoDataCallsLoaderAndImport() async throws {
        let mockLoader = MockDemoDataLoader()
        let mockImport = MockImportService()
        let testKey = SymmetricKey(size: .bits256)

        let seeder = DemoDataSeeder(
            demoDataLoader: mockLoader,
            importService: mockImport
        )

        try await seeder.seedDemoData(primaryKey: testKey)

        #expect(mockLoader.loadCalled == true)
        #expect(mockImport.importCallCount == 1)
    }

    @Test
    func seedDemoDataPassesPayloadToImportService() async throws {
        let mockLoader = MockDemoDataLoader()
        let expectedPersonCount = 5
        mockLoader.payload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(
                personCount: expectedPersonCount,
                recordCount: 0,
                attachmentCount: 0,
                schemaCount: 0
            ),
            persons: (0 ..< expectedPersonCount).map { index in
                PersonBackup(
                    id: UUID(),
                    name: "Test Person \(index)",
                    dateOfBirth: nil,
                    labels: [],
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            },
            records: [],
            attachments: [],
            schemas: []
        )

        let mockImport = MockImportService()
        let testKey = SymmetricKey(size: .bits256)

        let seeder = DemoDataSeeder(
            demoDataLoader: mockLoader,
            importService: mockImport
        )

        try await seeder.seedDemoData(primaryKey: testKey)

        #expect(mockImport.lastImportedPayload?.persons.count == expectedPersonCount)
    }

    @Test
    func seedDemoDataHandlesLoaderFailure() async throws {
        let mockLoader = MockDemoDataLoader()
        mockLoader.shouldFail = true

        let mockImport = MockImportService()
        let testKey = SymmetricKey(size: .bits256)

        let seeder = DemoDataSeeder(
            demoDataLoader: mockLoader,
            importService: mockImport
        )

        await #expect(throws: DemoDataLoaderError.self) {
            try await seeder.seedDemoData(primaryKey: testKey)
        }

        #expect(mockImport.importCallCount == 0)
    }

    @Test
    func seedDemoDataHandlesImportFailure() async throws {
        let mockLoader = MockDemoDataLoader()
        let mockImport = MockImportService()
        mockImport.shouldFail = true

        let testKey = SymmetricKey(size: .bits256)

        let seeder = DemoDataSeeder(
            demoDataLoader: mockLoader,
            importService: mockImport
        )

        await #expect(throws: BackupError.self) {
            try await seeder.seedDemoData(primaryKey: testKey)
        }
    }

    @Test
    func initWithDefaultsCreatesValidSeeder() {
        // Just verify the default initializer doesn't crash
        // Actual functionality tested with mocks
        // The initializer exercises makeDefaultImportService factory
        let seeder = DemoDataSeeder()
        _ = seeder // Use to silence warning
    }
}

// MARK: - Mock Demo Data Loader

final class MockDemoDataLoader: DemoDataLoaderProtocol, @unchecked Sendable {
    var loadCalled = false
    var shouldFail = false
    var payload = BackupPayload(
        exportedAt: Date(),
        appVersion: "1.0",
        metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
        persons: [],
        records: [],
        attachments: [],
        schemas: []
    )

    func loadDemoData() throws -> BackupPayload {
        loadCalled = true
        if shouldFail {
            throw DemoDataLoaderError.fileNotFound
        }
        return payload
    }
}
