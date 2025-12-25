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
}
