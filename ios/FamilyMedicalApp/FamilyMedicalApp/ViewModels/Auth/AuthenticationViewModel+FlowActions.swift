import Foundation
import OSLog

private let logger = Logger(subsystem: "com.cynexia.FamilyMedicalApp", category: "AuthFlow")

/// OPAQUE authentication flow actions for AuthenticationViewModel
extension AuthenticationViewModel {
    // MARK: - Username Flow Actions

    /// Submit username and determine if new or returning user
    /// With OPAQUE, we attempt login first - if user doesn't exist, we proceed to registration
    @MainActor
    func submitUsername() async {
        guard isUsernameValid else {
            errorMessage = "Please enter a valid username (at least 3 characters)"
            return
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        isLoading = true
        errorMessage = nil

        // With OPAQUE, we can't check if user exists without attempting auth
        // So we go directly to passphrase entry - the server will tell us if registration is needed
        // For now, we ask user to choose (this could be enhanced with a "check username" endpoint)
        flowState = .passphraseCreation(username: trimmedUsername)

        isLoading = false
    }

    /// For returning users who know their account exists
    @MainActor
    func proceedAsReturningUser() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        flowState = .passphraseEntry(username: trimmedUsername, isReturningUser: true)
    }

    @MainActor
    func submitPassphraseCreation() async {
        guard case let .passphraseCreation(username) = flowState else { return }

        // Validate passphrase strength
        let errors = validatePassphrase(passphrase)
        if !errors.isEmpty {
            errorMessage = errors.first?.errorDescription
            return
        }

        flowState = .passphraseConfirmation(username: username, passphrase: passphrase)
    }

    @MainActor
    func submitPassphraseConfirmation() async {
        guard case let .passphraseConfirmation(username, passphrase) = flowState else { return }

        guard confirmPassphrase == passphrase else {
            errorMessage = "Passphrases don't match"
            return
        }

        flowState = .biometricSetup(username: username, passphrase: passphrase, isReturningUser: false)
    }

    @MainActor
    func submitExistingPassphrase() async {
        guard case let .passphraseEntry(username, _) = flowState else { return }

        isLoading = true
        errorMessage = nil

        // Go to biometric setup, marking this as a returning user
        // The actual OPAQUE login will happen in completeSetup
        flowState = .biometricSetup(username: username, passphrase: passphrase, isReturningUser: true)

        isLoading = false
    }

    @MainActor
    func completeSetup(enableBiometric: Bool) async {
        guard case let .biometricSetup(username, passphrase, isReturningUser) = flowState else { return }

        isLoading = true
        errorMessage = nil

        do {
            if isReturningUser {
                // Returning user on new device: login with OPAQUE, then set up local account
                try await performLoginAndSetup(
                    password: passphrase,
                    username: username,
                    enableBiometric: enableBiometric
                )
            } else {
                // New user: register with OPAQUE
                try await performSetUp(password: passphrase, username: username, enableBiometric: enableBiometric)
            }
            isSetUp = true
            isAuthenticated = true
            flowState = .authenticated
            clearSensitiveFields()
        } catch {
            logger.error("[auth] Setup failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Flow Navigation

    func goBack() {
        switch flowState {
        case .passphraseCreation:
            flowState = .usernameEntry
            passphrase = ""
        case let .passphraseConfirmation(username, _):
            flowState = .passphraseCreation(username: username)
            confirmPassphrase = ""
        case .passphraseEntry:
            flowState = .usernameEntry
            passphrase = ""
        case let .biometricSetup(username, passphrase, isReturningUser):
            if isReturningUser {
                flowState = .passphraseEntry(username: username, isReturningUser: true)
            } else {
                flowState = .passphraseConfirmation(username: username, passphrase: passphrase)
            }
        default:
            break
        }
        errorMessage = nil
    }
}
