import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of RecordContentServiceProtocol for testing
final class MockRecordContentService: RecordContentServiceProtocol, @unchecked Sendable {
    // MARK: - Test Configuration

    var shouldFailEncrypt = false
    var shouldFailDecrypt = false

    // MARK: - Call Tracking

    var encryptCallCount = 0
    var decryptCallCount = 0

    // MARK: - Storage for Testing

    /// Store envelopes for retrieval during decrypt (bypassing real encryption)
    private var envelopeStore: [Data: RecordContentEnvelope] = [:]

    // MARK: - RecordContentServiceProtocol

    func encrypt(_ envelope: RecordContentEnvelope, using _: SymmetricKey) throws -> Data {
        encryptCallCount += 1

        if shouldFailEncrypt {
            throw RepositoryError.encryptionFailed("Mock encrypt failure")
        }

        // Create predictable encrypted data based on envelope
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(envelope)
        let encryptedData = Data(jsonData.reversed()) // Simple transformation for testing

        // Store for later retrieval
        envelopeStore[encryptedData] = envelope

        return encryptedData
    }

    func decrypt(_ encryptedData: Data, using _: SymmetricKey) throws -> RecordContentEnvelope {
        decryptCallCount += 1

        if shouldFailDecrypt {
            throw RepositoryError.decryptionFailed("Mock decrypt failure")
        }

        // Try to retrieve from store first
        if let envelope = envelopeStore[encryptedData] {
            return envelope
        }

        // Fallback: reverse the transformation
        let jsonData = Data(encryptedData.reversed())
        let decoder = JSONDecoder()
        return try decoder.decode(RecordContentEnvelope.self, from: jsonData)
    }

    // MARK: - Test Helpers

    func reset() {
        shouldFailEncrypt = false
        shouldFailDecrypt = false
        encryptCallCount = 0
        decryptCallCount = 0
        envelopeStore.removeAll()
    }

    /// Manually set encrypted data to return specific envelope (for testing decrypt)
    func setEnvelope(_ envelope: RecordContentEnvelope, for encryptedData: Data) {
        envelopeStore[encryptedData] = envelope
    }
}
