import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Fixtures & Helpers

struct DocumentFileStorageServiceTests {
    func makeService() throws -> (service: DocumentFileStorageService, tempDir: URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let service = DocumentFileStorageService(
            attachmentsDirectory: tempDir,
            logger: MockCategoryLogger(category: .storage)
        )
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
}

// MARK: - Store Tests

extension DocumentFileStorageServiceTests {
    @Test
    func store_validData_returnsURL() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(url.pathExtension == "enc")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func store_validData_writesCorrectContent() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
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
        let personId = UUID()
        let url1 = try service.store(encryptedData: data1, contentHMAC: hmac, personId: personId)
        let url2 = try service.store(encryptedData: data2, contentHMAC: hmac, personId: personId)
        #expect(url1 == url2)
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
        let personId = UUID()
        let url1 = try service.store(encryptedData: data1, contentHMAC: hmac1, personId: personId)
        let url2 = try service.store(encryptedData: data2, contentHMAC: hmac2, personId: personId)
        #expect(url1 != url2)
        let stored1 = try Data(contentsOf: url1)
        let stored2 = try Data(contentsOf: url2)
        #expect(stored1 == data1)
        #expect(stored2 == data2)
    }

    @Test
    func store_differentPersonIds_storeInSeparateSubdirectories() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId1 = UUID()
        let personId2 = UUID()
        let url1 = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId1)
        let url2 = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId2)
        #expect(url1 != url2)
        #expect(url1.path.contains(personId1.uuidString))
        #expect(url2.path.contains(personId2.uuidString))
    }

    @Test
    func store_generatesHexFilename() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = Data([0x01, 0x02, 0xAB, 0xCD])
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(url.lastPathComponent == "0102abcd.enc")
        #expect(url.path.contains(personId.uuidString))
    }

    @Test
    func store_emptyData_succeeds() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let emptyData = Data()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: emptyData, contentHMAC: hmac, personId: personId)
        let retrieved = try service.retrieve(contentHMAC: hmac, personId: personId)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(retrieved.isEmpty)
    }
}

// MARK: - Retrieve Tests

extension DocumentFileStorageServiceTests {
    @Test
    func retrieve_existingContent_returnsData() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        let retrieved = try service.retrieve(contentHMAC: hmac, personId: personId)
        #expect(retrieved == data)
    }

    @Test
    func retrieve_nonExistent_throwsNotFound() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let hmac = makeTestHMAC()
        let personId = UUID()
        #expect(throws: ModelError.self) {
            _ = try service.retrieve(contentHMAC: hmac, personId: personId)
        }
    }
}

// MARK: - Delete Tests

extension DocumentFileStorageServiceTests {
    @Test
    func delete_existingContent_removesFile() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(FileManager.default.fileExists(atPath: url.path))
        try service.delete(contentHMAC: hmac, personId: personId)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func delete_nonExistent_doesNotThrow() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let hmac = makeTestHMAC()
        let personId = UUID()
        try service.delete(contentHMAC: hmac, personId: personId)
    }
}

// MARK: - Exists Tests

extension DocumentFileStorageServiceTests {
    @Test
    func exists_existingContent_returnsTrue() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(service.exists(contentHMAC: hmac, personId: personId))
    }

    @Test
    func exists_nonExistent_returnsFalse() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let hmac = makeTestHMAC()
        let personId = UUID()
        #expect(!service.exists(contentHMAC: hmac, personId: personId))
    }

    @Test
    func exists_afterDelete_returnsFalse() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(service.exists(contentHMAC: hmac, personId: personId))
        try service.delete(contentHMAC: hmac, personId: personId)
        #expect(!service.exists(contentHMAC: hmac, personId: personId))
    }
}

// MARK: - listBlobs Tests

extension DocumentFileStorageServiceTests {
    @Test
    func listBlobs_noDirectory_returnsEmpty() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let blobs = try service.listBlobs(personId: UUID())
        #expect(blobs.isEmpty)
    }

    @Test
    func listBlobs_afterStore_returnsStoredHMAC() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        let blobs = try service.listBlobs(personId: personId)
        #expect(blobs.count == 1)
        #expect(blobs.contains(hmac))
    }

    @Test
    func listBlobs_afterDelete_excludesDeletedHMAC() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        try service.delete(contentHMAC: hmac, personId: personId)
        let blobs = try service.listBlobs(personId: personId)
        #expect(!blobs.contains(hmac))
    }

    @Test
    func listBlobs_onlyReturnsHMACsForRequestedPerson() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData()
        let hmac1 = makeTestHMAC()
        let hmac2 = makeTestHMAC()
        let personId1 = UUID()
        let personId2 = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac1, personId: personId1)
        _ = try service.store(encryptedData: data, contentHMAC: hmac2, personId: personId2)
        let blobs1 = try service.listBlobs(personId: personId1)
        let blobs2 = try service.listBlobs(personId: personId2)
        #expect(blobs1.contains(hmac1))
        #expect(!blobs1.contains(hmac2))
        #expect(blobs2.contains(hmac2))
        #expect(!blobs2.contains(hmac1))
    }

    @Test
    func listBlobs_ignoresMalformedFilenames_returnsValidOnly() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let personId = UUID()
        let goodHmac = Data([0xDE, 0xAD, 0xBE, 0xEF])
        // Store one well-formed blob so the person directory exists and contains a known entry.
        _ = try service.store(encryptedData: makeTestData(), contentHMAC: goodHmac, personId: personId)

        // Drop malformed `.enc` files directly into the person directory. Two distinct
        // rejection branches are exercised:
        //
        // Even-length guard (hex.count.isMultiple(of: 2) == false):
        //   - `not-hex.enc`: 7-char stem — odd length, rejected before per-char check
        //   - `abc.enc`: 3-char stem — odd length
        //
        // Per-character hex check (UInt8(_:radix:16) returns nil):
        //   - `abcg.enc`: 4-char stem, even length, but 'g' is not a hex digit
        //   - `zzzz.enc`: 4-char stem, even length, all chars non-hex — explicit
        //                 even-length-but-invalid-hex case
        let personDir = tempDir.appendingPathComponent(personId.uuidString, isDirectory: true)
        try Data().write(to: personDir.appendingPathComponent("not-hex.enc"))
        try Data().write(to: personDir.appendingPathComponent("abcg.enc"))
        try Data().write(to: personDir.appendingPathComponent("abc.enc"))
        try Data().write(to: personDir.appendingPathComponent("zzzz.enc"))
        // Also an empty stem: `.enc` (produced by e.g. a stray creation) must not yield an empty-HMAC set member.
        try Data().write(to: personDir.appendingPathComponent(".enc"))

        let blobs = try service.listBlobs(personId: personId)
        // Silently excluded, no throw; only the valid blob is returned.
        #expect(blobs == [goodHmac])
        #expect(!blobs.contains(Data()))
    }

    @Test
    func listBlobs_ignoresNonEncFiles_returnsValidOnly() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let personId = UUID()
        let goodHmac = Data([0x01, 0x23, 0x45, 0x67])
        _ = try service.store(encryptedData: makeTestData(), contentHMAC: goodHmac, personId: personId)

        let personDir = tempDir.appendingPathComponent(personId.uuidString, isDirectory: true)
        // Non-hidden files with wrong extensions must be excluded by the `pathExtension == "enc"`
        // guard. Using visible files here (not `.DS_Store`) ensures we exercise that filter
        // rather than the OS-level `.skipsHiddenFiles` option that would reject `.DS_Store`
        // before the extension check even runs.
        try Data("{}".utf8).write(to: personDir.appendingPathComponent("manifest.json"))
        try Data("junk".utf8).write(to: personDir.appendingPathComponent("junk.txt"))
        try Data().write(to: personDir.appendingPathComponent("notes.md"))

        let blobs = try service.listBlobs(personId: personId)
        #expect(blobs == [goodHmac])
    }
}

// MARK: - blobSize Tests

extension DocumentFileStorageServiceTests {
    @Test
    func blobSize_returnsCorrectSize() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData(size: 512)
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        let size = try service.blobSize(contentHMAC: hmac, personId: personId)
        #expect(size == UInt64(data.count))
    }

    @Test
    func blobSize_nonExistent_throws() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let hmac = makeTestHMAC()
        let personId = UUID()
        // Pin the error case: a missing blob must throw `.documentNotFound`, not
        // `.documentStorageFailed`. A future regression that swaps the guard for a
        // generic catch block will fail here.
        #expect {
            _ = try service.blobSize(contentHMAC: hmac, personId: personId)
        } throws: { error in
            guard case ModelError.documentNotFound = error else { return false }
            return true
        }
    }
}

// MARK: - Large File & Round-Trip Tests

extension DocumentFileStorageServiceTests {
    @Test
    func store_largeData_succeeds() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let data = makeTestData(size: 1_000_000)
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        let retrieved = try service.retrieve(contentHMAC: hmac, personId: personId)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(retrieved.count == data.count)
        #expect(retrieved == data)
    }

    @Test
    func storeRetrieve_roundTrip_preservesData() throws {
        let (service, tempDir) = try makeService()
        defer { cleanupTempDir(tempDir) }
        let originalData = Data("Test attachment content with special chars: 日本語 🎉".utf8)
        let hmac = makeTestHMAC()
        let personId = UUID()
        _ = try service.store(encryptedData: originalData, contentHMAC: hmac, personId: personId)
        let retrieved = try service.retrieve(contentHMAC: hmac, personId: personId)
        #expect(retrieved == originalData)
    }
}

// MARK: - Default Init Tests

extension DocumentFileStorageServiceTests {
    @Test
    func init_default_createsService() throws {
        let service = try DocumentFileStorageService()
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        let retrieved = try service.retrieve(contentHMAC: hmac, personId: personId)
        #expect(retrieved == data)
        try service.delete(contentHMAC: hmac, personId: personId)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func init_default_usesApplicationSupportDirectory() throws {
        let service = try DocumentFileStorageService()
        let data = makeTestData()
        let hmac = makeTestHMAC()
        let personId = UUID()
        let url = try service.store(encryptedData: data, contentHMAC: hmac, personId: personId)
        #expect(url.path.contains("Application Support"))
        #expect(url.path.contains("Attachments"))
        #expect(url.path.contains(personId.uuidString))
        try service.delete(contentHMAC: hmac, personId: personId)
    }

    @Test
    func init_default_createsDirectoryIfNotExists() throws {
        let service = try DocumentFileStorageService()
        #expect(service.exists(contentHMAC: makeTestHMAC(), personId: UUID()) == false)
    }
}
