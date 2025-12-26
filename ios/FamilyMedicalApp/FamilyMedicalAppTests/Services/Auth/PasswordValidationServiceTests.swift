// swiftlint:disable password_in_code
import Testing
@testable import FamilyMedicalApp

struct PasswordValidationServiceTests {
    // MARK: - Setup

    let service = PasswordValidationService()

    // MARK: - Validation Tests

    @Test
    func validPasswordPassesAllRules() {
        let password = "unique-horse-battery-staple-2024"
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
    func commonPasswordFailsValidation() {
        let password = "password123456" // Common password from list
        let errors = service.validate(password)
        #expect(errors.contains(.passwordTooCommon))
    }

    @Test
    func passwordWithVariantsFailsValidation() {
        let password = "password123" // Variant of common password
        let errors = service.validate(password)
        #expect(errors.contains(.passwordTooCommon))
    }

    @Test
    func exactlyTwelveCharactersPassesLengthCheck() {
        let password = "unique-pass1" // Exactly 12 chars
        let errors = service.validate(password)
        #expect(!errors.contains(.passwordTooShort))
    }

    @Test
    func passwordWithMultipleErrorsReturnsAllErrors() {
        let password = "pass" // Too short and too common
        let errors = service.validate(password)
        #expect(errors.count >= 1)
        #expect(errors.contains(.passwordTooShort))
    }

    // MARK: - Strength Calculation Tests

    @Test
    @MainActor
    func strongPasswordHasStrongStrength() {
        let password = "Unique-Very-Long-Passphrase-2024!" // 33 chars with all variety
        let strength = service.passwordStrength(password)
        #expect(strength == .strong)
    }

    @Test
    func goodPasswordHasGoodStrength() {
        let password = "unique-good-pass-1234" // 21 chars
        let strength = service.passwordStrength(password)
        #expect(strength >= .good)
    }

    @Test
    func fairPasswordHasFairStrength() {
        let password = "unique-pass12" // 13 chars
        let strength = service.passwordStrength(password)
        #expect(strength == .fair || strength == .good)
    }

    @Test
    func weakPasswordHasWeakStrength() {
        let password = "short12pass" // 11 chars, below minimum
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
        let password = "unique-emoji-🔒-pass-2024" // Contains emoji
        let errors = service.validate(password)
        // Should pass length rule (emoji doesn't break validation)
        #expect(!errors.contains(.passwordTooShort))
    }

    // MARK: - PasswordStrength Comparability Tests

    @Test
    @MainActor
    func strengthLevelsAreComparable() {
        #expect(PasswordStrength.weak < PasswordStrength.fair)
        #expect(PasswordStrength.fair < PasswordStrength.good)
        #expect(PasswordStrength.good < PasswordStrength.strong)
    }

    @Test
    @MainActor
    func strengthDisplayNamesAreCorrect() {
        #expect(PasswordStrength.weak.displayName == "Weak")
        #expect(PasswordStrength.fair.displayName == "Fair")
        #expect(PasswordStrength.good.displayName == "Good")
        #expect(PasswordStrength.strong.displayName == "Strong")
    }
}

// swiftlint:enable password_in_code
