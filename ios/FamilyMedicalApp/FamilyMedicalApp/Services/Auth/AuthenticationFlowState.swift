import Foundation

/// State machine for multi-step authentication flow
///
/// This enum represents all possible states during the authentication process,
/// supporting both new user registration and returning user login flows.
///
/// ## New User Flow (OPAQUE Registration)
/// `.usernameEntry` → `.passphraseCreation` → `.passphraseConfirmation` → `.biometricSetup` → `.authenticated`
///
/// ## Returning User Flow (OPAQUE Login)
/// `.usernameEntry` → `.passphraseEntry` → `.biometricSetup` → `.authenticated`
///
/// ## Daily Unlock (existing device)
/// `.unlock` → `.authenticated`
enum AuthenticationFlowState: Equatable {
    // MARK: - Initial State

    /// Username entry (both new and returning users start here)
    case usernameEntry

    // MARK: - New User States

    /// New user: create passphrase (with strength validation)
    case passphraseCreation(username: String)

    /// New user: confirm passphrase matches
    case passphraseConfirmation(username: String, passphrase: String)

    // MARK: - Returning User States

    /// Returning user: enter existing passphrase
    case passphraseEntry(username: String, isReturningUser: Bool)

    // MARK: - Common States

    /// Optional biometric setup (Face ID / Touch ID)
    /// - Parameters:
    ///   - username: The username
    ///   - passphrase: The passphrase
    ///   - isReturningUser: true if returning user on new device (needs loginAndSetup), false for new registration
    case biometricSetup(username: String, passphrase: String, isReturningUser: Bool = false)

    /// Daily unlock (existing device with setup complete)
    case unlock

    /// Authenticated - show main app
    case authenticated
}
