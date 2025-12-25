import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct FamilyMemberKeyServiceTests {
    let service = FamilyMemberKeyService()
    let keychainService = KeychainService()

    /// Test FMK generation produces 256-bit keys
    @Test
    func generateFMK_keySize() {
        let fmk = service.generateFMK()

        let fmkData = fmk.withUnsafeBytes { Data($0) }
        #expect(fmkData.count == 32) // 256 bits
    }

    /// Test FMK generation produces unique keys
    @Test
    func generateFMK_uniqueness() {
        let fmk1 = service.generateFMK()
        let fmk2 = service.generateFMK()
        let fmk3 = service.generateFMK()

        let data1 = fmk1.withUnsafeBytes { Data($0) }
        let data2 = fmk2.withUnsafeBytes { Data($0) }
        let data3 = fmk3.withUnsafeBytes { Data($0) }

        #expect(data1 != data2)
        #expect(data2 != data3)
        #expect(data1 != data3)
    }

    /// Test FMK wrap and unwrap round-trip
    @Test
    func wrapUnwrapFMK_roundTrip() throws {
        let fmk = service.generateFMK()
        let primaryKey = SymmetricKey(size: .bits256)

        let wrapped = try service.wrapFMK(fmk, with: primaryKey)
        let unwrapped = try service.unwrapFMK(wrapped, with: primaryKey)

        let originalData = fmk.withUnsafeBytes { Data($0) }
        let unwrappedData = unwrapped.withUnsafeBytes { Data($0) }

        #expect(originalData == unwrappedData)
    }

    /// Test unwrapping with wrong master key fails
    @Test
    func unwrapFMK_wrongPrimaryKey() throws {
        let fmk = service.generateFMK()
        let correctPrimaryKey = SymmetricKey(size: .bits256)
        let wrongPrimaryKey = SymmetricKey(size: .bits256)

        let wrapped = try service.wrapFMK(fmk, with: correctPrimaryKey)

        #expect(throws: CryptoError.self) {
            _ = try service.unwrapFMK(wrapped, with: wrongPrimaryKey)
        }
    }

    /// Test storing FMK persists to Keychain
    @Test
    func storeFMK_persistsToKeychain() throws {
        let fmk = service.generateFMK()
        let primaryKey = SymmetricKey(size: .bits256)
        let familyMemberID = "test-member-\(UUID().uuidString)"

        // Store FMK
        try service.storeFMK(fmk, familyMemberID: familyMemberID, primaryKey: primaryKey)

        // Verify it exists in Keychain
        let identifier = "fmk.\(familyMemberID)"
        #expect(keychainService.keyExists(identifier: identifier))

        // Cleanup
        try keychainService.deleteKey(identifier: identifier)
    }

    /// Test retrieving FMK with correct master key
    @Test
    func retrieveFMK_withCorrectPrimaryKey() throws {
        let fmk = service.generateFMK()
        let primaryKey = SymmetricKey(size: .bits256)
        let familyMemberID = "test-retrieve-\(UUID().uuidString)"

        // Store FMK
        try service.storeFMK(fmk, familyMemberID: familyMemberID, primaryKey: primaryKey)

        // Retrieve FMK
        let retrieved = try service.retrieveFMK(familyMemberID: familyMemberID, primaryKey: primaryKey)

        // Compare keys
        let originalData = fmk.withUnsafeBytes { Data($0) }
        let retrievedData = retrieved.withUnsafeBytes { Data($0) }
        #expect(originalData == retrievedData)

        // Cleanup
        let identifier = "fmk.\(familyMemberID)"
        try keychainService.deleteKey(identifier: identifier)
    }

    /// Test retrieving FMK with wrong master key fails
    @Test
    func retrieveFMK_wrongPrimaryKey() throws {
        let fmk = service.generateFMK()
        let correctPrimaryKey = SymmetricKey(size: .bits256)
        let wrongPrimaryKey = SymmetricKey(size: .bits256)
        let familyMemberID = "test-wrong-key-\(UUID().uuidString)"

        // Store with correct key
        try service.storeFMK(fmk, familyMemberID: familyMemberID, primaryKey: correctPrimaryKey)

        // Try to retrieve with wrong key
        #expect(throws: CryptoError.self) {
            _ = try service.retrieveFMK(familyMemberID: familyMemberID, primaryKey: wrongPrimaryKey)
        }

        // Cleanup
        let identifier = "fmk.\(familyMemberID)"
        try keychainService.deleteKey(identifier: identifier)
    }

    /// Test retrieving non-existent FMK throws error
    @Test
    func retrieveFMK_nonExistent() throws {
        let primaryKey = SymmetricKey(size: .bits256)
        let familyMemberID = "non-existent-\(UUID().uuidString)"

        #expect(throws: KeychainError.self) {
            _ = try service.retrieveFMK(familyMemberID: familyMemberID, primaryKey: primaryKey)
        }
    }

    /// Test wrapped FMK is different from original
    @Test
    func wrapFMK_producesDifferentData() throws {
        let fmk = service.generateFMK()
        let primaryKey = SymmetricKey(size: .bits256)

        let originalData = fmk.withUnsafeBytes { Data($0) }
        let wrapped = try service.wrapFMK(fmk, with: primaryKey)

        // Wrapped data should be different from original
        #expect(wrapped != originalData)

        // Wrapped data should be larger (includes wrapping overhead)
        #expect(wrapped.count > originalData.count)
    }
}
