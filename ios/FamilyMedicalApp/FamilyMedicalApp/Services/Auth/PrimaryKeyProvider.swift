import CryptoKit
import Foundation

/// Protocol for providing the primary key from Keychain
protocol PrimaryKeyProviderProtocol: Sendable {
    /// Retrieve the primary key from Keychain
    /// - Returns: The primary key
    /// - Throws: KeychainError if key cannot be retrieved
    func getPrimaryKey() throws -> SymmetricKey
}

/// Provides access to the user's primary key stored in Keychain after authentication
final class PrimaryKeyProvider: PrimaryKeyProviderProtocol, @unchecked Sendable {
    // MARK: - Constants

    private static let primaryKeyIdentifier = "com.family-medical-app.primary-key"

    // MARK: - Dependencies

    private let keychainService: KeychainServiceProtocol

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol? = nil) {
        self.keychainService = keychainService ?? KeychainService()
    }

    // MARK: - PrimaryKeyProviderProtocol

    func getPrimaryKey() throws -> SymmetricKey {
        try keychainService.retrieveKey(identifier: Self.primaryKeyIdentifier)
    }
}
