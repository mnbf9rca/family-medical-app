// swiftlint:disable password_in_code
import Testing
@testable import FamilyMedicalApp

struct PasswordValidationServiceTests {
    // MARK: - Setup

    let service = PasswordValidationService()

    // MARK: - Validation Tests

    @Test
    func validPasswordPassesAllRules() {
        let password = "MySecurePass123!"
        let errors = service.validate(password)
        #expect(errors.isEmpty)
    }

    @Test
    func tooShortPasswordFailsValidation() {
        let password = "Short1!" // Only 7 chars
        let errors = service.validate(password)
        #expect(errors.contains(.passwordTooShort))
    }

    @Test
    func passwordWithoutUppercaseFailsValidation() {
        let password = "mysecurepass123!"
        let errors = service.validate(password)
        #expect(errors.contains(.passwordMissingUppercase))
    }

    @Test
    func passwordWithoutLowercaseFailsValidation() {
        let password = "MYSECUREPASS123!"
        let errors = service.validate(password)
        #expect(errors.contains(.passwordMissingLowercase))
    }

    @Test
    func passwordWithoutDigitFailsValidation() {
        let password = "MySecurePass!"
        let errors = service.validate(password)
        #expect(errors.contains(.passwordMissingDigit))
    }

    @Test
    func passwordWithoutSpecialCharacterFailsValidation() {
        let password = "MySecurePass123"
        let errors = service.validate(password)
        #expect(errors.contains(.passwordMissingSpecialCharacter))
    }

    @Test
    func passwordWithMultipleErrorsReturnsAllErrors() {
        let password = "short" // Too short, missing uppercase, digit, and special char
        let errors = service.validate(password)
        #expect(errors.count >= 4)
        #expect(errors.contains(.passwordTooShort))
        #expect(errors.contains(.passwordMissingUppercase))
        #expect(errors.contains(.passwordMissingDigit))
        #expect(errors.contains(.passwordMissingSpecialCharacter))
    }

    @Test
    func exactlyTwelveCharactersPassesLengthCheck() {
        let password = "MyPassword1!" // Exactly 12 chars
        let errors = service.validate(password)
        #expect(!errors.contains(.passwordTooShort))
    }

    // MARK: - Strength Calculation Tests

    @Test
    func strongPasswordHasStrongStrength() {
        let password = "MyVerySecurePassword123!" // 24 chars, all types
        let strength = service.passwordStrength(password)
        #expect(strength == .strong)
    }

    @Test
    func goodPasswordHasGoodStrength() {
        let password = "MyGoodPass123!" // 14 chars, all types
        let strength = service.passwordStrength(password)
        #expect(strength >= .good)
    }

    @Test
    func fairPasswordHasFairStrength() {
        let password = "password123" // Missing uppercase and special char
        let strength = service.passwordStrength(password)
        #expect(strength == .fair || strength == .weak)
    }

    @Test
    func weakPasswordHasWeakStrength() {
        let password = "password" // Missing uppercase, digit, special char
        let strength = service.passwordStrength(password)
        #expect(strength == .weak)
    }

    // MARK: - Edge Cases

    @Test
    func emptyPasswordFailsValidation() {
        let password = ""
        let errors = service.validate(password)
        #expect(!errors.isEmpty)
        #expect(errors.contains(.passwordTooShort))
    }

    @Test
    func passwordWithUnicodeCharactersValidates() {
        let password = "MyPassword123!🔒" // Contains emoji
        let errors = service.validate(password)
        // Should pass all rules (emoji doesn't break validation)
        #expect(errors.isEmpty)
    }

    @Test
    func passwordWithAllSpecialCharactersValidates() {
        let specialChars = "!@#$%^&*(),.?\":{}|<>"
        for char in specialChars {
            let password = "MyPassword123\(char)"
            let errors = service.validate(password)
            #expect(
                !errors.contains(.passwordMissingSpecialCharacter),
                "Special character '\(char)' should be recognized"
            )
        }
    }

    // MARK: - PasswordStrength Comparability Tests

    @Test
    func strengthLevelsAreComparable() {
        #expect(PasswordStrength.weak < PasswordStrength.fair)
        #expect(PasswordStrength.fair < PasswordStrength.good)
        #expect(PasswordStrength.good < PasswordStrength.strong)
    }

    @Test
    func strengthDisplayNamesAreCorrect() {
        #expect(PasswordStrength.weak.displayName == "Weak")
        #expect(PasswordStrength.fair.displayName == "Fair")
        #expect(PasswordStrength.good.displayName == "Good")
        #expect(PasswordStrength.strong.displayName == "Strong")
    }
}

// swiftlint:enable password_in_code
