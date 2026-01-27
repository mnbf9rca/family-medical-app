import Foundation

/// Email verification flow actions for AuthenticationViewModel
extension AuthenticationViewModel {
    // MARK: - Email Verification Flow Actions

    @MainActor
    func submitEmail() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await performSendVerificationCode(to: email)
            flowState = .codeVerification(email: email)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Unable to send verification code"
        }

        isLoading = false
    }

    @MainActor
    func submitVerificationCode() async {
        guard verificationCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code"
            return
        }

        guard case let .codeVerification(email) = flowState else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await performVerifyCode(verificationCode, for: email)
            if result.isValid {
                if result.isReturningUser {
                    flowState = .passphraseEntry(email: email, isReturningUser: true)
                } else {
                    flowState = .passphraseCreation(email: email)
                }
            }
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Verification failed"
        }

        isLoading = false
    }

    @MainActor
    func resendVerificationCode() async {
        guard case let .codeVerification(email) = flowState else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await performSendVerificationCode(to: email)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Unable to resend code"
        }

        isLoading = false
    }

    @MainActor
    func submitPassphraseCreation() async {
        guard case let .passphraseCreation(email) = flowState else { return }

        // Validate passphrase strength
        let errors = validatePassphrase(passphrase)
        if !errors.isEmpty {
            errorMessage = errors.first?.errorDescription
            return
        }

        flowState = .passphraseConfirmation(email: email, passphrase: passphrase)
    }

    @MainActor
    func submitPassphraseConfirmation() async {
        guard case let .passphraseConfirmation(email, passphrase) = flowState else { return }

        guard confirmPassphrase == passphrase else {
            errorMessage = "Passphrases don't match"
            return
        }

        flowState = .biometricSetup(email: email, passphrase: passphrase)
    }

    @MainActor
    func submitExistingPassphrase() async {
        guard case let .passphraseEntry(email, _) = flowState else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await performUnlockWithPassword(passphrase)
            flowState = .biometricSetup(email: email, passphrase: passphrase)
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Invalid passphrase"
        }

        isLoading = false
    }

    @MainActor
    func completeSetup(enableBiometric: Bool) async {
        guard case let .biometricSetup(email, passphrase) = flowState else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await performSetUp(password: passphrase, email: email, enableBiometric: enableBiometric)
            isSetUp = true
            isAuthenticated = true
            flowState = .authenticated
            clearSensitiveFields()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Flow Navigation

    func goBack() {
        switch flowState {
        case .codeVerification:
            flowState = .emailEntry
            verificationCode = ""
        case let .passphraseCreation(email):
            flowState = .codeVerification(email: email)
            passphrase = ""
        case let .passphraseConfirmation(email, _):
            flowState = .passphraseCreation(email: email)
            confirmPassphrase = ""
        case let .passphraseEntry(email, _):
            flowState = .codeVerification(email: email)
            passphrase = ""
        case let .biometricSetup(email, passphrase):
            flowState = .passphraseConfirmation(email: email, passphrase: passphrase)
        default:
            break
        }
        errorMessage = nil
    }
}
