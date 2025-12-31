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

    /// Store content for retrieval during decrypt (bypassing real encryption)
    private var contentStore: [Data: RecordContent] = [:]

    // MARK: - RecordContentServiceProtocol

    func encrypt(_ content: RecordContent, using fmk: SymmetricKey) throws -> Data {
        encryptCallCount += 1

        if shouldFailEncrypt {
            throw RepositoryError.encryptionFailed("Mock encrypt failure")
        }

        // Create predictable encrypted data based on content
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(content)
        let encryptedData = Data(jsonData.reversed()) // Simple transformation for testing

        // Store for later retrieval
        contentStore[encryptedData] = content

        return encryptedData
    }

    func decrypt(_ encryptedData: Data, using fmk: SymmetricKey) throws -> RecordContent {
        decryptCallCount += 1

        if shouldFailDecrypt {
            throw RepositoryError.decryptionFailed("Mock decrypt failure")
        }

        // Try to retrieve from store first
        if let content = contentStore[encryptedData] {
            return content
        }

        // Fallback: reverse the transformation
        let jsonData = Data(encryptedData.reversed())
        let decoder = JSONDecoder()
        return try decoder.decode(RecordContent.self, from: jsonData)
    }

    // MARK: - Test Helpers

    func reset() {
        shouldFailEncrypt = false
        shouldFailDecrypt = false
        encryptCallCount = 0
        decryptCallCount = 0
        contentStore.removeAll()
    }

    /// Manually set encrypted data to return specific content (for testing decrypt)
    func setContent(_ content: RecordContent, for encryptedData: Data) {
        contentStore[encryptedData] = content
    }
}
