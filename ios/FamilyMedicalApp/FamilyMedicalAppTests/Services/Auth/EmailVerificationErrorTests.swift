import Testing
@testable import FamilyMedicalApp

struct EmailVerificationErrorTests {
    // MARK: - Email Verification Error Descriptions

    @Test
    func emailVerificationFailedHasDescription() {
        let error = AuthenticationError.emailVerificationFailed
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("verification") == true)
    }

    @Test
    func invalidVerificationCodeHasDescription() {
        let error = AuthenticationError.invalidVerificationCode
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Invalid") == true || error.errorDescription?.contains("code") == true)
    }

    @Test
    func verificationCodeExpiredHasDescription() {
        let error = AuthenticationError.verificationCodeExpired
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("expired") == true)
    }

    @Test
    func tooManyVerificationAttemptsHasDescription() {
        let error = AuthenticationError.tooManyVerificationAttempts
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("many") == true || error.errorDescription?.contains("wait") == true)
    }

    // MARK: - Equatable Conformance

    @Test
    func emailVerificationErrorsAreEqual() {
        let error1 = AuthenticationError.emailVerificationFailed
        let error2 = AuthenticationError.emailVerificationFailed
        #expect(error1 == error2)
    }

    @Test
    func differentEmailVerificationErrorsAreNotEqual() {
        let errors: [AuthenticationError] = [
            .emailVerificationFailed,
            .invalidVerificationCode,
            .verificationCodeExpired,
            .tooManyVerificationAttempts
        ]

        for (index, error) in errors.enumerated() {
            for (otherIndex, otherError) in errors.enumerated() where index != otherIndex {
                #expect(error != otherError)
            }
        }
    }
}
