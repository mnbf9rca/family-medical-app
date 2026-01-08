import Foundation
import Testing
@testable import FamilyMedicalApp

struct AttachmentFileStorageServiceTests {
    // MARK: - Test Fixtures

    func makeService() throws -> (service: AttachmentFileStorageService, tempDir: URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let service = AttachmentFileStorageService(attachmentsDirectory: tempDir)
        return (service, tempDir)
    }

    func cleanupTempDir(_ tempDir: URL) {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func makeTestHMAC() -> Data {
        Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
    }

    func makeTestData(size: Int = 1_024) -> Data {
        Data((0 ..< size).map { _ in UInt8.random(in: 0 ... 255) })
    }

    // MARK: - Store Tests

    @Test
    func store_validData_returnsURL() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)

        #expect(url.pathExtension == "enc")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func store_validData_writesCorrectContent() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)
        let storedData = try Data(contentsOf: url)

        #expect(storedData == data)
    }

    @Test
    func store_duplicateHMAC_doesNotOverwrite() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data1 = makeTestData()
        let data2 = makeTestData()
        let hmac = makeTestHMAC()

        let url1 = try service.store(encryptedData: data1, contentHMAC: hmac)
        let url2 = try service.store(encryptedData: data2, contentHMAC: hmac)

        // Same URL returned
        #expect(url1 == url2)

        // Original data preserved
        let storedData = try Data(contentsOf: url1)
        #expect(storedData == data1)
    }

    @Test
    func store_differentHMACs_storesSeparateFiles() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data1 = makeTestData()
        let data2 = makeTestData()
        let hmac1 = makeTestHMAC()
        let hmac2 = makeTestHMAC()

        let url1 = try service.store(encryptedData: data1, contentHMAC: hmac1)
        let url2 = try service.store(encryptedData: data2, contentHMAC: hmac2)

        #expect(url1 != url2)

        let stored1 = try Data(contentsOf: url1)
        let stored2 = try Data(contentsOf: url2)

        #expect(stored1 == data1)
        #expect(stored2 == data2)
    }

    // MARK: - Retrieve Tests

    @Test
    func retrieve_existingContent_returnsData() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        _ = try service.store(encryptedData: data, contentHMAC: hmac)
        let retrieved = try service.retrieve(contentHMAC: hmac)

        #expect(retrieved == data)
    }

    @Test
    func retrieve_nonExistent_throwsNotFound() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let hmac = makeTestHMAC()

        #expect(throws: ModelError.self) {
            _ = try service.retrieve(contentHMAC: hmac)
        }
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingContent_removesFile() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)
        #expect(FileManager.default.fileExists(atPath: url.path))

        try service.delete(contentHMAC: hmac)

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func delete_nonExistent_doesNotThrow() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let hmac = makeTestHMAC()

        // Should not throw (idempotent)
        try service.delete(contentHMAC: hmac)
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingContent_returnsTrue() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        _ = try service.store(encryptedData: data, contentHMAC: hmac)

        #expect(service.exists(contentHMAC: hmac))
    }

    @Test
    func exists_nonExistent_returnsFalse() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let hmac = makeTestHMAC()

        #expect(!service.exists(contentHMAC: hmac))
    }

    @Test
    func exists_afterDelete_returnsFalse() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        let hmac = makeTestHMAC()

        _ = try service.store(encryptedData: data, contentHMAC: hmac)
        #expect(service.exists(contentHMAC: hmac))

        try service.delete(contentHMAC: hmac)
        #expect(!service.exists(contentHMAC: hmac))
    }

    // MARK: - File Naming Tests

    @Test
    func store_generatesHexFilename() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let data = makeTestData()
        // Known HMAC for predictable filename
        let hmac = Data([0x01, 0x02, 0xAB, 0xCD])

        let url = try service.store(encryptedData: data, contentHMAC: hmac)

        let expectedName = "0102abcd.enc"
        #expect(url.lastPathComponent == expectedName)
    }

    // MARK: - Large File Tests

    @Test
    func store_largeData_succeeds() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        // 1 MB of data
        let data = makeTestData(size: 1_000_000)
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)
        let retrieved = try service.retrieve(contentHMAC: hmac)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(retrieved.count == data.count)
        #expect(retrieved == data)
    }

    // MARK: - Round-Trip Tests

    @Test
    func storeRetrieve_roundTrip_preservesData() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let originalData = Data("Test attachment content with special chars: 日本語 🎉".utf8)
        let hmac = makeTestHMAC()

        _ = try service.store(encryptedData: originalData, contentHMAC: hmac)
        let retrieved = try service.retrieve(contentHMAC: hmac)

        #expect(retrieved == originalData)
    }

    // MARK: - Default Init Tests

    @Test
    func init_default_createsService() throws {
        // This tests the default init that creates the Application Support/Attachments directory
        let service = try AttachmentFileStorageService()

        // Verify service is functional by storing and retrieving
        let data = makeTestData()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)
        let retrieved = try service.retrieve(contentHMAC: hmac)

        #expect(retrieved == data)

        // Clean up
        try service.delete(contentHMAC: hmac)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func init_default_usesApplicationSupportDirectory() throws {
        let service = try AttachmentFileStorageService()
        let data = makeTestData()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: data, contentHMAC: hmac)

        // Verify the URL is in Application Support/Attachments
        #expect(url.path.contains("Application Support"))
        #expect(url.path.contains("Attachments"))

        // Clean up
        try service.delete(contentHMAC: hmac)
    }

    @Test
    func init_default_createsDirectoryIfNotExists() throws {
        // This tests that createAttachmentsDirectory is called and works
        // The directory might already exist, so this just ensures no error
        let service = try AttachmentFileStorageService()
        #expect(service.exists(contentHMAC: makeTestHMAC()) == false)
    }

    // MARK: - Error Handling Tests

    @Test
    func store_emptyData_succeeds() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }

        let emptyData = Data()
        let hmac = makeTestHMAC()

        let url = try service.store(encryptedData: emptyData, contentHMAC: hmac)
        let retrieved = try service.retrieve(contentHMAC: hmac)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(retrieved.isEmpty)
    }
}
