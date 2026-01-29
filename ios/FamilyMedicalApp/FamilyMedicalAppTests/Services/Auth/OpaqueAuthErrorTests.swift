import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for OpaqueAuthError localized descriptions
struct OpaqueAuthErrorTests {
    // MARK: - Error Descriptions

    @Test
    func registrationFailedHasDescription() {
        let error = OpaqueAuthError.registrationFailed
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Registration failed") == true)
    }

    @Test
    func authenticationFailedHasDescription() {
        let error = OpaqueAuthError.authenticationFailed
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Authentication failed") == true)
    }

    @Test
    func networkErrorHasDescription() {
        let error = OpaqueAuthError.networkError
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Network error") == true)
    }

    @Test
    func invalidResponseHasDescription() {
        let error = OpaqueAuthError.invalidResponse
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Invalid response") == true)
    }

    @Test
    func serverErrorHasDescription() {
        let error = OpaqueAuthError.serverError(statusCode: 500)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("500") == true)
    }

    @Test
    func protocolErrorHasDescription() {
        let error = OpaqueAuthError.protocolError
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("protocol error") == true)
    }

    @Test
    func rateLimitedWithRetryAfterHasDescription() {
        let error = OpaqueAuthError.rateLimited(retryAfter: 60)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("60") == true)
    }

    @Test
    func rateLimitedWithoutRetryAfterHasDescription() {
        let error = OpaqueAuthError.rateLimited(retryAfter: nil)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("later") == true)
    }

    @Test
    func sessionExpiredHasDescription() {
        let error = OpaqueAuthError.sessionExpired
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Session expired") == true)
    }

    @Test
    func uploadFailedHasDescription() {
        let error = OpaqueAuthError.uploadFailed
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("Failed to upload") == true)
    }

    @Test
    func accountExistsConfirmedHasDescription() {
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let error = OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("already have an account") == true)
    }

    // MARK: - Equatable Conformance

    @Test
    func equalErrorsAreEqual() {
        let error1 = OpaqueAuthError.networkError
        let error2 = OpaqueAuthError.networkError
        #expect(error1 == error2)
    }

    @Test
    func differentErrorsAreNotEqual() {
        let error1 = OpaqueAuthError.networkError
        let error2 = OpaqueAuthError.invalidResponse
        #expect(error1 != error2)
    }

    @Test
    func serverErrorsWithSameStatusAreEqual() {
        let error1 = OpaqueAuthError.serverError(statusCode: 500)
        let error2 = OpaqueAuthError.serverError(statusCode: 500)
        #expect(error1 == error2)
    }

    @Test
    func serverErrorsWithDifferentStatusAreNotEqual() {
        let error1 = OpaqueAuthError.serverError(statusCode: 500)
        let error2 = OpaqueAuthError.serverError(statusCode: 503)
        #expect(error1 != error2)
    }

    @Test
    func rateLimitedErrorsWithSameRetryAreEqual() {
        let error1 = OpaqueAuthError.rateLimited(retryAfter: 30)
        let error2 = OpaqueAuthError.rateLimited(retryAfter: 30)
        #expect(error1 == error2)
    }

    @Test
    func rateLimitedErrorsWithDifferentRetryAreNotEqual() {
        let error1 = OpaqueAuthError.rateLimited(retryAfter: 30)
        let error2 = OpaqueAuthError.rateLimited(retryAfter: 60)
        #expect(error1 != error2)
    }

    @Test
    func accountExistsConfirmedWithSameResultAreEqual() {
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let error1 = OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        let error2 = OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        #expect(error1 == error2)
    }

    @Test
    func accountExistsConfirmedWithDifferentResultsAreNotEqual() {
        let loginResult1 = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let loginResult2 = OpaqueLoginResult(
            exportKey: Data(repeating: 0x99, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        let error1 = OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult1)
        let error2 = OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult2)
        #expect(error1 != error2)
    }
}
