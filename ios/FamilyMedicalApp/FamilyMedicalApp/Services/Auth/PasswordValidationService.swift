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

/// Service for validating passwords following NIST SP 800-63B guidelines
final class PasswordValidationService: PasswordValidationServiceProtocol {
    // MARK: - Constants

    private static let minimumLength = 12

    // Common passwords loaded from SecLists (10,000 most common)
    // Source: https://github.com/danielmiessler/SecLists/blob/master/Passwords/Common-Credentials/10k-most-common.txt
    private static let commonPasswords: Set<String> = {
        guard let fileURL = Bundle.main.url(forResource: "common-passwords", withExtension: "txt"),
              let contents = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            // Fallback to basic list if file not found
            return [
                "password", "123456", "123456789", "12345678", "12345", "1234567",
                "qwerty", "abc123", "password1", "111111", "123123", "admin"
            ]
        }

        return Set(contents.split(separator: "\n").map { String($0).lowercased() })
    }()

    // MARK: - Public Methods

    func validate(_ password: String) -> [AuthenticationError] {
        var errors = Set<AuthenticationError>()

        // NIST Rule 1: Minimum length (12 chars is good)
        if password.count < Self.minimumLength {
            errors.insert(.passwordTooShort)
        }

        // NIST Rule 2: Check against common passwords (case-insensitive)
        let lowercasePassword = password.lowercased()
        if Self.commonPasswords.contains(lowercasePassword) {
            errors.insert(.passwordTooCommon)
        }

        // Also check for common patterns with numbers appended (password1, password123, etc.)
        let basePassword = lowercasePassword.trimmingCharacters(in: .decimalDigits)
        if basePassword != lowercasePassword, Self.commonPasswords.contains(basePassword) {
            errors.insert(.passwordTooCommon)
        }

        // Also check for common patterns with special chars (password!, password!!, etc.)
        let alphanumericPassword = String(lowercasePassword.filter { $0.isLetter || $0.isNumber })
        if alphanumericPassword != lowercasePassword, Self.commonPasswords.contains(alphanumericPassword) {
            errors.insert(.passwordTooCommon)
        }

        return Array(errors)
    }

    func passwordStrength(_ password: String) -> PasswordStrength {
        var score = 0

        // Length-based scoring (NIST emphasizes length over complexity)
        switch password.count {
        case 0 ..< 12:
            score += 0 // Too short
        case 12 ..< 16:
            score += 1 // Minimum acceptable
        case 16 ..< 20:
            score += 2 // Good length
        case 20...:
            score += 3 // Excellent length
        default:
            score += 0
        }

        // Character variety bonus (max 2 points, not required but helps)
        score += characterVarietyBonus(password)

        // Check for repetitive patterns (penalty)
        if hasRepetitivePatterns(password) {
            score -= 1
        }

        // Check if it's a common password (penalty)
        if Self.commonPasswords.contains(password.lowercased()) {
            score -= 2
        }

        // Map score to strength
        return switch max(0, score) {
        case 0 ... 1:
            .weak
        case 2:
            .fair
        case 3 ... 4:
            .good
        case 5...:
            .strong
        default:
            .weak
        }
    }

    // MARK: - Private Methods

    private func characterVarietyBonus(_ password: String) -> Int {
        var varietyScore = 0
        if password.contains(where: \.isUppercase) { varietyScore += 1 }
        if password.contains(where: \.isLowercase) { varietyScore += 1 }
        if password.contains(where: \.isNumber) { varietyScore += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { varietyScore += 1 }

        if varietyScore >= 4 { return 2 }
        if varietyScore >= 3 { return 1 }
        return 0
    }

    private func hasRepetitivePatterns(_ password: String) -> Bool {
        // Check for simple repetition like "aaaa", "1111", "abcabc"
        if password.count >= 4 {
            let chars = Array(password)
            // Check for 4+ repeated characters
            for index in 0 ..< chars.count - 3 {
                let allMatch = chars[index] == chars[index + 1] &&
                    chars[index] == chars[index + 2] &&
                    chars[index] == chars[index + 3]
                if allMatch {
                    return true
                }
            }
        }
        return false
    }
}
