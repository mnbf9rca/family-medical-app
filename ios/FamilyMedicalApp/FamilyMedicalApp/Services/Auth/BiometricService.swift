import Foundation
import LocalAuthentication

/// Type of biometric authentication available
enum BiometryType {
    case none
    case touchID
    case faceID
}

/// Protocol for biometric authentication service
protocol BiometricServiceProtocol {
    /// The type of biometry available on this device
    var biometryType: BiometryType { get }

    /// Whether biometric authentication is available
    var isBiometricAvailable: Bool { get }

    /// Authenticate using biometrics
    /// - Parameter reason: The reason to display to the user
    /// - Throws: AuthenticationError if authentication fails
    func authenticate(reason: String) async throws
}

/// Service for managing biometric authentication
final class BiometricService: BiometricServiceProtocol {
    // MARK: - Properties

    private let context: LAContext

    // MARK: - Initialization

    init(context: LAContext = LAContext()) {
        self.context = context
    }

    // MARK: - BiometricServiceProtocol

    var biometryType: BiometryType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async throws {
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw AuthenticationError.biometricNotAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw AuthenticationError.biometricNotEnrolled
                default:
                    throw AuthenticationError.biometricFailed(error.localizedDescription)
                }
            }
            throw AuthenticationError.biometricNotAvailable
        }

        // Attempt biometric authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if !success {
                throw AuthenticationError.biometricFailed("Authentication failed")
            }
        } catch let error as LAError {
            switch error.code {
            case .appCancel, .systemCancel, .userCancel:
                throw AuthenticationError.biometricCancelled
            case .biometryNotAvailable:
                throw AuthenticationError.biometricNotAvailable
            case .biometryNotEnrolled:
                throw AuthenticationError.biometricNotEnrolled
            default:
                throw AuthenticationError.biometricFailed(error.localizedDescription)
            }
        } catch {
            throw AuthenticationError.biometricFailed(error.localizedDescription)
        }
    }
}
