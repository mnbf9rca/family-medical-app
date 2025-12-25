import Foundation

/// Password strength levels
enum PasswordStrength: Int, Comparable, CaseIterable {
    case weak = 1
    case fair = 2
    case good = 3
    case strong = 4

    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .weak: "Weak"
        case .fair: "Fair"
        case .good: "Good"
        case .strong: "Strong"
        }
    }
}

/// Protocol for password validation service
protocol PasswordValidationServiceProtocol {
    /// Validates a password against all rules
    /// - Parameter password: The password to validate
    /// - Returns: Array of validation errors (empty if valid)
    func validate(_ password: String) -> [AuthenticationError]

    /// Calculates the strength of a password
    /// - Parameter password: The password to evaluate
    /// - Returns: Password strength level
    func passwordStrength(_ password: String) -> PasswordStrength
}

/// Service for validating password complexity and calculating strength
final class PasswordValidationService: PasswordValidationServiceProtocol {
    // MARK: - Constants

    private static let minimumLength = 12
    private static let specialCharacters = "!@#$%^&*(),.?\":{}|<>"

    // MARK: - Public Methods

    func validate(_ password: String) -> [AuthenticationError] {
        var errors: [AuthenticationError] = []

        // Check minimum length
        if password.count < Self.minimumLength {
            errors.append(.passwordTooShort)
        }

        // Check for uppercase letter
        if !password.contains(where: \.isUppercase) {
            errors.append(.passwordMissingUppercase)
        }

        // Check for lowercase letter
        if !password.contains(where: \.isLowercase) {
            errors.append(.passwordMissingLowercase)
        }

        // Check for digit
        if !password.contains(where: \.isNumber) {
            errors.append(.passwordMissingDigit)
        }

        // Check for special character
        if !password.contains(where: { Self.specialCharacters.contains($0) }) {
            errors.append(.passwordMissingSpecialCharacter)
        }

        return errors
    }

    func passwordStrength(_ password: String) -> PasswordStrength {
        var score = 0

        // Length contribution (max 2 points)
        if password.count >= 12 {
            score += 1
        }
        if password.count >= 16 {
            score += 1
        }

        // Character variety (max 4 points)
        if password.contains(where: \.isUppercase) {
            score += 1
        }
        if password.contains(where: \.isLowercase) {
            score += 1
        }
        if password.contains(where: \.isNumber) {
            score += 1
        }
        if password.contains(where: { Self.specialCharacters.contains($0) }) {
            score += 1
        }

        // Map score to strength
        switch score {
        case 0 ... 2:
            return .weak
        case 3 ... 4:
            return .fair
        case 5:
            return .good
        case 6...:
            return .strong
        default:
            return .weak
        }
    }
}
