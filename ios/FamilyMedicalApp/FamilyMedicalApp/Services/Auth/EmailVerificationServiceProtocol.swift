import Foundation

/// Result of email verification
struct EmailVerificationResult: Equatable, Sendable {
    /// Whether the verification code was valid
    let isValid: Bool

    /// Whether this email has been seen before (returning user)
    let isReturningUser: Bool
}

/// Protocol for email verification service
///
/// This protocol enables dependency injection and mocking for the email
/// verification flow. The service handles sending verification codes via
/// email and validating them.
///
/// ## Security Notes
/// - Email addresses are hashed client-side before being sent to the server
/// - The server only sees `SHA256(email + app_salt)`, never the actual email
/// - Rate limiting protects against abuse
protocol EmailVerificationServiceProtocol: Sendable {
    /// Send verification code to email
    ///
    /// Sends a 6-digit verification code to the specified email address.
    /// The code expires after 5 minutes.
    ///
    /// - Parameter email: The email address to send the code to
    /// - Throws: `AuthenticationError.emailVerificationFailed` if sending fails
    /// - Throws: `AuthenticationError.tooManyVerificationAttempts` if rate limited
    func sendVerificationCode(to email: String) async throws

    /// Verify the 6-digit code
    ///
    /// Validates the provided code against the one sent to the email.
    /// Codes are single-use and expire after 5 minutes.
    ///
    /// - Parameters:
    ///   - code: The 6-digit verification code
    ///   - email: The email address the code was sent to
    /// - Returns: Result indicating validity and whether user is returning
    /// - Throws: `AuthenticationError.invalidVerificationCode` if code is wrong
    /// - Throws: `AuthenticationError.verificationCodeExpired` if code expired
    func verifyCode(_ code: String, for email: String) async throws -> EmailVerificationResult
}
