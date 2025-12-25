import Foundation

/// Errors that can occur during authentication operations
enum AuthenticationError: LocalizedError, Equatable {
    // Biometric errors
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricFailed(String)
    case biometricCancelled

    // Password validation errors
    case passwordTooShort
    case passwordMissingUppercase
    case passwordMissingLowercase
    case passwordMissingDigit
    case passwordMissingSpecialCharacter
    case passwordMismatch

    // Authentication errors
    case wrongPassword
    case notSetUp
    case accountLocked(remainingSeconds: Int)
    case verificationFailed
    case keychainError(String)

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
        case .passwordMissingUppercase:
            return "Password must contain at least one uppercase letter"
        case .passwordMissingLowercase:
            return "Password must contain at least one lowercase letter"
        case .passwordMissingDigit:
            return "Password must contain at least one digit"
        case .passwordMissingSpecialCharacter:
            return "Password must contain at least one special character (!@#$%^&*(),.?\":{}|<>)"
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
        }
    }
}
