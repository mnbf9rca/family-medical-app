import Foundation
import Observation

@Observable
final class SecuritySettingsViewModel {
    // MARK: - Properties

    var biometryType: BiometryType {
        biometricService.biometryType
    }

    var isBiometricEnabled: Bool {
        authService.isBiometricEnabled
    }

    var isBiometricAvailable: Bool {
        biometricService.isBiometricAvailable
    }

    var lockTimeoutMinutes: Int {
        get {
            lockStateService.lockTimeoutSeconds / 60
        }
        set {
            lockStateService.lockTimeoutSeconds = newValue * 60
        }
    }

    var errorMessage: String?
    var isLoading = false

    // MARK: - Dependencies

    private let authService: AuthenticationServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let lockStateService: LockStateServiceProtocol

    // MARK: - Initialization

    init(
        authService: AuthenticationServiceProtocol = AuthenticationService(),
        biometricService: BiometricServiceProtocol = BiometricService(),
        lockStateService: LockStateServiceProtocol = LockStateService()
    ) {
        self.authService = authService
        self.biometricService = biometricService
        self.lockStateService = lockStateService
    }

    // MARK: - Actions

    @MainActor
    func toggleBiometric() async {
        isLoading = true
        errorMessage = nil

        if isBiometricEnabled {
            authService.disableBiometric()
        } else {
            do {
                try await authService.enableBiometric()
            } catch let error as AuthenticationError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func updateLockTimeout(_ minutes: Int) {
        lockTimeoutMinutes = minutes
    }

    func manualLock() {
        lockStateService.lock()
    }
}
