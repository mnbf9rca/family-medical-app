import Foundation

/// Errors that can occur during authentication operations
enum AuthenticationError: LocalizedError, Equatable, Hashable {
    // Biometric errors
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricFailed(String)
    case biometricCancelled

    // Password validation errors
    case passwordTooShort
    case passwordTooCommon
    case passwordMismatch

    // Authentication errors
    case wrongPassword
    case notSetUp
    case accountLocked(remainingSeconds: Int)
    case verificationFailed
    case keychainError(String)
    case networkError(String)
    case opaqueError(String)

    // Email verification errors
    case emailVerificationFailed
    case invalidVerificationCode
    case verificationCodeExpired
    case tooManyVerificationAttempts

    var errorDescription: String? {
        switch self {
        // Biometric errors
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
        case let .biometricFailed(reason):
            return "Biometric authentication failed: \(reason)"
        case .biometricCancelled:
            return "Biometric authentication was cancelled"
        // Password validation errors
        case .passwordTooShort:
            return "Password must be at least 12 characters long"
        case .passwordTooCommon:
            return "This password is too common. Please choose a more unique password"
        case .passwordMismatch:
            return "Passwords do not match"
        // Authentication errors
        case .wrongPassword:
            return "Incorrect password"
        case .notSetUp:
            return "User account has not been set up"
        case let .accountLocked(remainingSeconds):
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            if minutes > 0 {
                return "Too many failed attempts. Try again in \(minutes)m \(seconds)s"
            } else {
                return "Too many failed attempts. Try again in \(seconds)s"
            }
        case .verificationFailed:
            return "Authentication verification failed"
        case let .keychainError(message):
            return "Keychain error: \(message)"
        case let .networkError(message):
            return "Network error: \(message)"
        case let .opaqueError(message):
            return "Authentication error: \(message)"
        // Email verification errors
        case .emailVerificationFailed:
            return "Unable to send verification code. Please try again."
        case .invalidVerificationCode:
            return "Invalid code. Please check and try again."
        case .verificationCodeExpired:
            return "Code expired. Please request a new one."
        case .tooManyVerificationAttempts:
            return "Too many attempts. Please wait before trying again."
        }
    }
}
