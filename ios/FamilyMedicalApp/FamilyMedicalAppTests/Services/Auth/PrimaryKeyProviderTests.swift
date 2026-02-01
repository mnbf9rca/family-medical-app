import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct PrimaryKeyProviderTests {
    // MARK: - Normal Mode Tests

    @Test
    func getPrimaryKeyRetrievesKeyFromKeychain() throws {
        // Create test key
        let testKey = SymmetricKey(size: .bits256)
        let mockKeychain = MockKeychainService()
        mockKeychain.storedKeys["com.family-medical-app.primary-key"] = testKey
        let mockLockState = MockLockStateService()

        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Retrieve key
        let retrievedKey = try provider.getPrimaryKey()

        // Verify key matches
        #expect(retrievedKey.withUnsafeBytes { Data($0) } == testKey.withUnsafeBytes { Data($0) })
    }

    @Test
    func getPrimaryKeyThrowsWhenKeyNotFound() throws {
        let mockKeychain = MockKeychainService()
        let mockLockState = MockLockStateService()
        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Expect error when no key exists
        #expect(throws: KeychainError.self) {
            try provider.getPrimaryKey()
        }
    }

    @Test
    func getPrimaryKeyUsesCorrectIdentifier() {
        let mockKeychain = MockKeychainService()
        let mockLockState = MockLockStateService()
        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Try to get key (will fail, but we can verify the identifier used)
        _ = try? provider.getPrimaryKey()

        // Verify the correct identifier was requested
        #expect(mockKeychain.lastRetrievedIdentifier == "com.family-medical-app.primary-key")
    }

    // MARK: - Demo Mode Tests

    @Test
    func getPrimaryKeyUsesDemoIdentifierWhenInDemoMode() {
        let mockKeychain = MockKeychainService()
        let mockLockState = MockLockStateService()
        mockLockState.isDemoMode = true

        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Try to get key (will fail, but we can verify the identifier used)
        _ = try? provider.getPrimaryKey()

        // Verify the demo identifier was requested
        #expect(mockKeychain.lastRetrievedIdentifier == DemoModeService.demoPrimaryKeyIdentifier)
    }

    @Test
    func getPrimaryKeyRetrievesDemoKeyWhenInDemoMode() throws {
        let testKey = SymmetricKey(size: .bits256)
        let mockKeychain = MockKeychainService()
        mockKeychain.storedKeys[DemoModeService.demoPrimaryKeyIdentifier] = testKey
        let mockLockState = MockLockStateService()
        mockLockState.isDemoMode = true

        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Retrieve key
        let retrievedKey = try provider.getPrimaryKey()

        // Verify key matches the demo key
        #expect(retrievedKey.withUnsafeBytes { Data($0) } == testKey.withUnsafeBytes { Data($0) })
    }

    @Test
    func getPrimaryKeyThrowsInDemoModeWhenDemoKeyNotFound() {
        let mockKeychain = MockKeychainService()
        let mockLockState = MockLockStateService()
        mockLockState.isDemoMode = true
        let provider = PrimaryKeyProvider(keychainService: mockKeychain, lockStateService: mockLockState)

        // Expect error when demo key doesn't exist
        #expect(throws: KeychainError.self) {
            try provider.getPrimaryKey()
        }
    }
}

// MARK: - Mock KeychainService

private final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    var storedKeys: [String: SymmetricKey] = [:]
    var storedData: [String: Data] = [:]
    var lastRetrievedIdentifier: String?

    // swiftlint:disable:next unneeded_throws_rethrows
    func storeKey(_ key: SymmetricKey, identifier: String, accessControl: KeychainAccessControl) throws {
        storedKeys[identifier] = key
    }

    func retrieveKey(identifier: String) throws -> SymmetricKey {
        lastRetrievedIdentifier = identifier
        guard let key = storedKeys[identifier] else {
            throw KeychainError.keyNotFound(identifier)
        }
        return key
    }

    // swiftlint:disable:next unneeded_throws_rethrows
    func deleteKey(identifier: String) throws {
        storedKeys.removeValue(forKey: identifier)
    }

    func keyExists(identifier: String) -> Bool {
        storedKeys[identifier] != nil
    }

    // swiftlint:disable:next unneeded_throws_rethrows
    func storeData(_ data: Data, identifier: String, accessControl: KeychainAccessControl) throws {
        storedData[identifier] = data
    }

    func retrieveData(identifier: String) throws -> Data {
        guard let data = storedData[identifier] else {
            throw KeychainError.keyNotFound(identifier)
        }
        return data
    }

    // swiftlint:disable:next unneeded_throws_rethrows
    func deleteData(identifier: String) throws {
        storedData.removeValue(forKey: identifier)
    }

    func dataExists(identifier: String) -> Bool {
        storedData[identifier] != nil
    }
}
