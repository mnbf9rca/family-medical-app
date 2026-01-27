import Foundation

/// State machine for multi-step authentication flow
///
/// This enum represents all possible states during the authentication process,
/// supporting both new user registration and returning user login flows.
///
/// ## New User Flow
/// `.emailEntry` → `.codeVerification` → `.passphraseCreation` → `.passphraseConfirmation` → `.biometricSetup` →
/// `.authenticated`
///
/// ## Returning User Flow
/// `.emailEntry` → `.codeVerification` → `.passphraseEntry` → `.biometricSetup` → `.authenticated`
///
/// ## Daily Unlock (existing device)
/// `.unlock` → `.authenticated`
enum AuthenticationFlowState: Equatable {
    // MARK: - Initial State

    /// Email entry (both new and returning users start here)
    case emailEntry

    // MARK: - Verification States

    /// Code verification after email submitted
    case codeVerification(email: String)

    // MARK: - New User States

    /// New user: create passphrase (with strength validation)
    case passphraseCreation(email: String)

    /// New user: confirm passphrase matches
    case passphraseConfirmation(email: String, passphrase: String)

    // MARK: - Returning User States

    /// Returning user: enter existing passphrase
    case passphraseEntry(email: String, isReturningUser: Bool)

    // MARK: - Common States

    /// Optional biometric setup (Face ID / Touch ID)
    case biometricSetup(email: String, passphrase: String)

    /// Daily unlock (existing device with setup complete)
    case unlock

    /// Authenticated - show main app
    case authenticated
}
