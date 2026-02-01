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
///
/// This provider automatically handles demo mode by checking the lock state and
/// retrieving from the appropriate keychain identifier (production vs demo).
final class PrimaryKeyProvider: PrimaryKeyProviderProtocol, @unchecked Sendable {
    // MARK: - Constants

    private static let primaryKeyIdentifier = "com.family-medical-app.primary-key"

    // MARK: - Dependencies

    private let keychainService: KeychainServiceProtocol
    private let lockStateService: LockStateServiceProtocol

    // MARK: - Initialization

    init(
        keychainService: KeychainServiceProtocol? = nil,
        lockStateService: LockStateServiceProtocol? = nil
    ) {
        self.keychainService = keychainService ?? KeychainService()
        self.lockStateService = lockStateService ?? LockStateService()
    }

    // MARK: - PrimaryKeyProviderProtocol

    func getPrimaryKey() throws -> SymmetricKey {
        // Check if in demo mode - use demo key identifier
        if lockStateService.isDemoMode {
            return try keychainService.retrieveKey(identifier: DemoModeService.demoPrimaryKeyIdentifier)
        }
        // Normal mode - use production key identifier
        return try keychainService.retrieveKey(identifier: Self.primaryKeyIdentifier)
    }
}
