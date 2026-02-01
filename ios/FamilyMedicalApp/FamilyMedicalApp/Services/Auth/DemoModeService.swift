import CryptoKit
import Foundation

/// Protocol for demo mode management
protocol DemoModeServiceProtocol: Sendable {
    /// Enter demo mode - creates demo account with deterministic key
    func enterDemoMode() async throws

    /// Exit demo mode - deletes all demo data
    func exitDemoMode() async

    /// Check if currently in demo mode
    var isInDemoMode: Bool { get }
}

/// Service for managing demo mode account and data
final class DemoModeService: DemoModeServiceProtocol, @unchecked Sendable {
    // MARK: - Demo Credentials (Deterministic)

    /// Fixed demo username (not for real accounts)
    static let demoUsername = "demo-user"

    /// Fixed demo passphrase (not for real accounts)
    static let demoPassphrase = "Demo-Mode-Sample-2024!"

    // MARK: - Demo Keychain Identifiers

    /// Demo primary key identifier (isolated from real keys)
    static let demoPrimaryKeyIdentifier = "com.family-medical-app.demo.primary-key"
    static let demoIdentityPrivateKeyIdentifier = "com.family-medical-app.demo.identity-private-key"
    static let demoVerificationTokenIdentifier = "com.family-medical-app.demo.verification-token"

    // MARK: - UserDefaults Keys

    private static let demoUsernameKey = "com.family-medical-app.demo.username"

    // MARK: - Dependencies

    private let keychainService: KeychainServiceProtocol
    private var lockStateService: LockStateServiceProtocol
    private let userDefaults: UserDefaults
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        lockStateService: LockStateServiceProtocol = LockStateService(),
        userDefaults: UserDefaults = .standard,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.keychainService = keychainService
        self.lockStateService = lockStateService
        self.userDefaults = userDefaults
        self.logger = logger ?? LoggingService.shared.logger(category: .auth)
    }

    // MARK: - DemoModeServiceProtocol

    var isInDemoMode: Bool {
        lockStateService.isDemoMode
    }

    func enterDemoMode() async throws {
        logger.logOperation("enterDemoMode", state: "started")

        // Generate deterministic demo primary key
        // Note: For demo mode, we derive a key from fixed credentials
        // This is intentionally less secure but isolated from real accounts
        let demoKeyData = Data(Self.demoPassphrase.utf8)
        let demoKey = SymmetricKey(data: SHA256.hash(data: demoKeyData))

        // Store demo key in Keychain with demo identifier
        try keychainService.storeKey(
            demoKey,
            identifier: Self.demoPrimaryKeyIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        // Store demo username
        userDefaults.set(Self.demoUsername, forKey: Self.demoUsernameKey)

        // Set demo mode flag
        lockStateService.isDemoMode = true

        logger.logOperation("enterDemoMode", state: "completed")
    }

    func exitDemoMode() async {
        logger.logOperation("exitDemoMode", state: "started")

        // Delete demo Keychain items
        try? keychainService.deleteKey(identifier: Self.demoPrimaryKeyIdentifier)
        try? keychainService.deleteData(identifier: Self.demoIdentityPrivateKeyIdentifier)
        try? keychainService.deleteData(identifier: Self.demoVerificationTokenIdentifier)

        // Clear demo UserDefaults
        userDefaults.removeObject(forKey: Self.demoUsernameKey)

        // Clear demo mode flag
        lockStateService.isDemoMode = false

        logger.logOperation("exitDemoMode", state: "completed")
    }
}
