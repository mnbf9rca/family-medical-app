import Testing
@testable import FamilyMedicalApp

struct AuthenticationErrorsTests {
    // MARK: - Biometric Error Descriptions

    @Test
    func biometricNotAvailableHasDescription() {
        let error = AuthenticationError.biometricNotAvailable
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("not available") == true)
    }

    @Test
    func biometricNotEnrolledHasDescription() {
        let error = AuthenticationError.biometricNotEnrolled
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("enrolled") == true)
    }

    @Test
    func biometricFailedHasDescription() {
        let error = AuthenticationError.biometricFailed("Test reason")
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Test reason") == true)
    }

    @Test
    func biometricCancelledHasDescription() {
        let error = AuthenticationError.biometricCancelled
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    // MARK: - Password Validation Error Descriptions

    @Test
    func passwordTooShortHasDescription() {
        let error = AuthenticationError.passwordTooShort
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("12") == true)
    }

    @Test
    func passwordTooCommonHasDescription() {
        let error = AuthenticationError.passwordTooCommon
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("common") == true)
    }

    @Test
    func passwordMismatchHasDescription() {
        let error = AuthenticationError.passwordMismatch
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("do not match") == true)
    }

    // MARK: - Authentication Error Descriptions

    @Test
    func wrongPasswordHasDescription() {
        let error = AuthenticationError.wrongPassword
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Incorrect") == true)
    }

    @Test
    func notSetUpHasDescription() {
        let error = AuthenticationError.notSetUp
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("not been set up") == true)
    }

    @Test
    func accountLockedHasDescriptionWithTime() {
        let error = AuthenticationError.accountLocked(remainingSeconds: 90)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("1m 30s") == true)
    }

    @Test
    func accountLockedHandlesSecondsOnly() {
        let error = AuthenticationError.accountLocked(remainingSeconds: 45)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("45s") == true)
        #expect(error.errorDescription?.contains("0m") == false)
    }

    @Test
    func verificationFailedHasDescription() {
        let error = AuthenticationError.verificationFailed
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("verification") == true)
    }

    @Test
    func keychainErrorHasDescription() {
        let error = AuthenticationError.keychainError("Test error")
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Test error") == true)
    }

    // MARK: - Equatable Conformance

    @Test
    func equalErrorsAreEqual() {
        let error1 = AuthenticationError.wrongPassword
        let error2 = AuthenticationError.wrongPassword
        #expect(error1 == error2)
    }

    @Test
    func differentErrorsAreNotEqual() {
        let error1 = AuthenticationError.wrongPassword
        let error2 = AuthenticationError.notSetUp
        #expect(error1 != error2)
    }

    @Test
    func errorsWithSameAssociatedValuesAreEqual() {
        let error1 = AuthenticationError.biometricFailed("reason")
        let error2 = AuthenticationError.biometricFailed("reason")
        #expect(error1 == error2)
    }

    @Test
    func errorsWithDifferentAssociatedValuesAreNotEqual() {
        let error1 = AuthenticationError.biometricFailed("reason1")
        let error2 = AuthenticationError.biometricFailed("reason2")
        #expect(error1 != error2)
    }
}
