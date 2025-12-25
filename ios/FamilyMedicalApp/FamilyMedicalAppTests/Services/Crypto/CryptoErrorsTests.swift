import Foundation
import Testing
@testable import FamilyMedicalApp

struct CryptoErrorsTests {
    // MARK: - CryptoError Tests

    @Test
    func encryptionFailedErrorDescription() {
        let error = CryptoError.encryptionFailed("test reason")
        #expect(error.errorDescription == "Encryption failed: test reason")
    }

    @Test
    func decryptionFailedErrorDescription() {
        let error = CryptoError.decryptionFailed("test reason")
        #expect(error.errorDescription == "Decryption failed: test reason")
    }

    @Test
    func keyDerivationFailedErrorDescription() {
        let error = CryptoError.keyDerivationFailed("test reason")
        #expect(error.errorDescription == "Key derivation failed: test reason")
    }

    @Test
    func invalidSaltErrorDescription() {
        let error = CryptoError.invalidSalt("test reason")
        #expect(error.errorDescription == "Invalid salt: test reason")
    }

    @Test
    func invalidPayloadErrorDescription() {
        let error = CryptoError.invalidPayload("test reason")
        #expect(error.errorDescription == "Invalid payload: test reason")
    }

    @Test
    func invalidKeySizeErrorDescription() {
        let error = CryptoError.invalidKeySize
        #expect(error.errorDescription == "Invalid key size - must be 256 bits")
    }

    @Test
    func cryptoErrorEquality() {
        let error1 = CryptoError.encryptionFailed("same")
        let error2 = CryptoError.encryptionFailed("same")
        let error3 = CryptoError.encryptionFailed("different")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    // MARK: - KeychainError Tests

    @Test
    func storeFailedErrorDescription() {
        let error = KeychainError.storeFailed(-25_300)
        #expect(error.errorDescription == "Keychain store failed with status: -25300")
    }

    @Test
    func retrieveFailedErrorDescription() {
        let error = KeychainError.retrieveFailed(-25_300)
        #expect(error.errorDescription == "Keychain retrieve failed with status: -25300")
    }

    @Test
    func deleteFailedErrorDescription() {
        let error = KeychainError.deleteFailed(-25_300)
        #expect(error.errorDescription == "Keychain delete failed with status: -25300")
    }

    @Test
    func keyNotFoundErrorDescription() {
        let error = KeychainError.keyNotFound("test.identifier")
        #expect(error.errorDescription == "Key not found in Keychain: test.identifier")
    }

    @Test
    func keychainErrorEquality() {
        let error1 = KeychainError.storeFailed(-25_300)
        let error2 = KeychainError.storeFailed(-25_300)
        let error3 = KeychainError.storeFailed(-25_301)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
