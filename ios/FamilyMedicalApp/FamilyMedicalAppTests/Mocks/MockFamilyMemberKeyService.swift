import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock family member key service for testing
/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
final class MockFamilyMemberKeyService: FamilyMemberKeyServiceProtocol, @unchecked Sendable {
    // MARK: - Configuration

    var shouldFailGenerate = false
    var shouldFailWrap = false
    var shouldFailUnwrap = false
    var shouldFailStore = false
    var shouldFailRetrieve = false

    // MARK: - Storage

    /// In-memory FMK storage (keyed by family member ID)
    private(set) var storedFMKs: [String: SymmetricKey] = [:]

    // MARK: - Tracking

    private(set) var generateCalls: Int = 0
    private(set) var wrapCalls: [(fmk: SymmetricKey, primaryKey: SymmetricKey)] = []
    private(set) var unwrapCalls: [(wrappedFMK: Data, primaryKey: SymmetricKey)] = []
    private(set) var storeCallsCount: Int = 0 // Simplified to avoid large tuple lint error
    private(set) var retrieveCalls: [(id: String, primaryKey: SymmetricKey)] = []

    // MARK: - FamilyMemberKeyServiceProtocol

    func generateFMK() -> SymmetricKey {
        generateCalls += 1

        if shouldFailGenerate {
            // Can't throw from this method, so return a zero key to simulate failure
            return SymmetricKey(data: Data(repeating: 0, count: 32))
        }

        // Generate a real key for testing
        return SymmetricKey(size: .bits256)
    }

    func wrapFMK(_ fmk: SymmetricKey, with primaryKey: SymmetricKey) throws -> Data {
        wrapCalls.append((fmk, primaryKey))

        if shouldFailWrap {
            throw CryptoError.encryptionFailed("Mock wrap failure")
        }

        // Return predictable wrapped key data
        let fmkData = fmk.withUnsafeBytes { Data($0) }
        return Data(repeating: 0x05, count: fmkData.count + 8) // Simulated wrapped size
    }

    func unwrapFMK(_ wrappedFMK: Data, with primaryKey: SymmetricKey) throws -> SymmetricKey {
        unwrapCalls.append((wrappedFMK, primaryKey))

        if shouldFailUnwrap {
            throw CryptoError.decryptionFailed("Mock unwrap failure")
        }

        // Return a real symmetric key for testing
        return SymmetricKey(size: .bits256)
    }

    func storeFMK(_ fmk: SymmetricKey, familyMemberID: String, primaryKey: SymmetricKey) throws {
        storeCallsCount += 1

        if shouldFailStore {
            throw KeychainError.storeFailed(-1)
        }

        // Store in memory
        storedFMKs[familyMemberID] = fmk
    }

    func retrieveFMK(familyMemberID: String, primaryKey: SymmetricKey) throws -> SymmetricKey {
        retrieveCalls.append((familyMemberID, primaryKey))

        if shouldFailRetrieve {
            throw KeychainError.retrieveFailed(-1)
        }

        guard let fmk = storedFMKs[familyMemberID] else {
            throw KeychainError.keyNotFound(familyMemberID)
        }

        return fmk
    }

    // MARK: - Test Helpers

    func reset() {
        generateCalls = 0
        wrapCalls.removeAll()
        unwrapCalls.removeAll()
        storeCallsCount = 0
        retrieveCalls.removeAll()
        storedFMKs.removeAll()

        shouldFailGenerate = false
        shouldFailWrap = false
        shouldFailUnwrap = false
        shouldFailStore = false
        shouldFailRetrieve = false
    }

    /// Pre-populate an FMK for a family member (for testing retrieval)
    func setFMK(_ fmk: SymmetricKey, for familyMemberID: String) {
        storedFMKs[familyMemberID] = fmk
    }
}
