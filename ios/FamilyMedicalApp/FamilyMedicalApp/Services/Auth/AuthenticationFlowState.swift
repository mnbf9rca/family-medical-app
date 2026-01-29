import Foundation

/// State machine for multi-step authentication flow
///
/// This enum represents all possible states during the authentication process,
/// supporting both new user registration and returning user login flows.
///
/// ## New User Flow (OPAQUE Registration)
/// `.welcome` → `.usernameEntry(isNewUser: true)` → `.passphraseCreation` → `.passphraseConfirmation` →
/// `.biometricSetup` → `.authenticated`
///
/// ## Returning User Flow (OPAQUE Login)
/// `.welcome` → `.usernameEntry(isNewUser: false)` → `.passphraseEntry` → `.biometricSetup` → `.authenticated`
///
/// ## Daily Unlock (existing device)
/// `.unlock` → `.authenticated`
enum AuthenticationFlowState: Equatable {
    // MARK: - Initial State

    /// Welcome screen with options to create account or sign in
    case welcome

    /// Username entry - isNewUser determines the next step
    case usernameEntry(isNewUser: Bool)

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

    /// Account exists confirmation (user tried to register with existing username + correct password)
    /// - Parameters:
    ///   - username: The username
    ///   - loginResult: The pre-authenticated login result from the silent probe
    ///   - enableBiometric: Whether user wants biometric enabled
    case accountExistsConfirmation(username: String, loginResult: OpaqueLoginResult, enableBiometric: Bool)

    /// Daily unlock (existing device with setup complete)
    case unlock

    /// Authenticated - show main app
    case authenticated
}
