import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct KeychainServiceTests {
    let service = KeychainService()

    /// Test storing and retrieving a key
    @Test
    func storeAndRetrieveKey() throws {
        let testKey = SymmetricKey(size: .bits256)
        let identifier = "test-key-\(UUID().uuidString)"

        // Store key
        try service.storeKey(testKey, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Retrieve key
        let retrievedKey = try service.retrieveKey(identifier: identifier)

        // Compare keys
        let original = testKey.withUnsafeBytes { Data($0) }
        let retrieved = retrievedKey.withUnsafeBytes { Data($0) }
        #expect(original == retrieved)

        // Cleanup
        try service.deleteKey(identifier: identifier)
    }

    /// Test deleting a key
    @Test
    func deleteKey() throws {
        let testKey = SymmetricKey(size: .bits256)
        let identifier = "test-delete-\(UUID().uuidString)"

        // Store then delete
        try service.storeKey(testKey, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)
        try service.deleteKey(identifier: identifier)

        // Verify deleted
        #expect(!service.keyExists(identifier: identifier))

        // Attempting to retrieve should throw
        #expect(throws: KeychainError.self) {
            _ = try service.retrieveKey(identifier: identifier)
        }
    }

    /// Test retrieving a non-existent key throws error
    @Test
    func retrieveNonExistentKey() throws {
        let identifier = "non-existent-\(UUID().uuidString)"

        #expect(throws: KeychainError.keyNotFound(identifier)) {
            _ = try service.retrieveKey(identifier: identifier)
        }
    }

    /// Test keyExists returns correct value
    @Test
    func keyExists() throws {
        let testKey = SymmetricKey(size: .bits256)
        let identifier = "test-exists-\(UUID().uuidString)"

        // Should not exist initially
        #expect(!service.keyExists(identifier: identifier))

        // Store key
        try service.storeKey(testKey, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Should exist now
        #expect(service.keyExists(identifier: identifier))

        // Cleanup
        try service.deleteKey(identifier: identifier)

        // Should not exist after deletion
        #expect(!service.keyExists(identifier: identifier))
    }

    /// Test storing a key twice (upsert behavior)
    @Test
    func storeKeyTwice() throws {
        let firstKey = SymmetricKey(size: .bits256)
        let secondKey = SymmetricKey(size: .bits256)
        let identifier = "test-upsert-\(UUID().uuidString)"

        // Store first key
        try service.storeKey(firstKey, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Store second key with same identifier (should replace)
        try service.storeKey(secondKey, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Retrieve and verify it's the second key
        let retrievedKey = try service.retrieveKey(identifier: identifier)
        let secondData = secondKey.withUnsafeBytes { Data($0) }
        let retrievedData = retrievedKey.withUnsafeBytes { Data($0) }

        #expect(retrievedData == secondData)

        // Cleanup
        try service.deleteKey(identifier: identifier)
    }

    /// Test different access control levels
    @Test
    func accessControlLevels() throws {
        let testKey = SymmetricKey(size: .bits256)

        // Test whenUnlockedThisDeviceOnly
        let id1 = "test-access-1-\(UUID().uuidString)"
        try service.storeKey(testKey, identifier: id1, accessControl: .whenUnlockedThisDeviceOnly)
        #expect(service.keyExists(identifier: id1))
        try service.deleteKey(identifier: id1)

        // Test afterFirstUnlockThisDeviceOnly
        let id2 = "test-access-2-\(UUID().uuidString)"
        try service.storeKey(testKey, identifier: id2, accessControl: .afterFirstUnlockThisDeviceOnly)
        #expect(service.keyExists(identifier: id2))
        try service.deleteKey(identifier: id2)
    }

    // MARK: - Data Storage Tests

    /// Test storing and retrieving data
    @Test
    func storeAndRetrieveData() throws {
        let testData = Data("Test data content".utf8)
        let identifier = "test-data-\(UUID().uuidString)"

        // Store data
        try service.storeData(testData, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Retrieve data
        let retrievedData = try service.retrieveData(identifier: identifier)

        // Compare data
        #expect(retrievedData == testData)

        // Cleanup
        try service.deleteData(identifier: identifier)
    }

    /// Test deleting data
    @Test
    func deleteData() throws {
        let testData = Data("Test data".utf8)
        let identifier = "test-delete-data-\(UUID().uuidString)"

        // Store then delete
        try service.storeData(testData, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)
        try service.deleteData(identifier: identifier)

        // Verify deleted
        #expect(!service.dataExists(identifier: identifier))

        // Attempting to retrieve should throw
        #expect(throws: KeychainError.self) {
            _ = try service.retrieveData(identifier: identifier)
        }
    }

    /// Test retrieving non-existent data throws error
    @Test
    func retrieveNonExistentData() throws {
        let identifier = "non-existent-data-\(UUID().uuidString)"

        #expect(throws: KeychainError.keyNotFound(identifier)) {
            _ = try service.retrieveData(identifier: identifier)
        }
    }

    /// Test dataExists returns correct value
    @Test
    func dataExists() throws {
        let testData = Data("Test data".utf8)
        let identifier = "test-exists-data-\(UUID().uuidString)"

        // Should not exist initially
        #expect(!service.dataExists(identifier: identifier))

        // Store data
        try service.storeData(testData, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Should exist now
        #expect(service.dataExists(identifier: identifier))

        // Cleanup
        try service.deleteData(identifier: identifier)

        // Should not exist after deletion
        #expect(!service.dataExists(identifier: identifier))
    }

    /// Test storing data twice (upsert behavior)
    @Test
    func storeDataTwice() throws {
        let firstData = Data("First data".utf8)
        let secondData = Data("Second data".utf8)
        let identifier = "test-upsert-data-\(UUID().uuidString)"

        // Store first data
        try service.storeData(firstData, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Store second data with same identifier (should replace)
        try service.storeData(secondData, identifier: identifier, accessControl: .whenUnlockedThisDeviceOnly)

        // Retrieve and verify it's the second data
        let retrievedData = try service.retrieveData(identifier: identifier)

        #expect(retrievedData == secondData)

        // Cleanup
        try service.deleteData(identifier: identifier)
    }

    /// Test different access control levels for data
    @Test
    func dataAccessControlLevels() throws {
        let testData = Data("Test data".utf8)

        // Test whenUnlockedThisDeviceOnly
        let id1 = "test-data-access-1-\(UUID().uuidString)"
        try service.storeData(testData, identifier: id1, accessControl: .whenUnlockedThisDeviceOnly)
        #expect(service.dataExists(identifier: id1))
        try service.deleteData(identifier: id1)

        // Test afterFirstUnlockThisDeviceOnly
        let id2 = "test-data-access-2-\(UUID().uuidString)"
        try service.storeData(testData, identifier: id2, accessControl: .afterFirstUnlockThisDeviceOnly)
        #expect(service.dataExists(identifier: id2))
        try service.deleteData(identifier: id2)
    }
}
