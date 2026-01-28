import CryptoKit
import Foundation

/// Service for email-based verification
///
/// Handles sending verification codes to email addresses and validating them.
/// Uses zero-knowledge design where the server only sees hashed emails.
///
/// ## Test Email Bypass
/// In DEBUG builds, emails matching `test@example.com` or `*@test.example.com`
/// bypass actual API calls for testing purposes.
final class EmailVerificationService: EmailVerificationServiceProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    /// App constant salt for zero-knowledge email hashing
    /// This ensures hashes are app-specific and can't be rainbow-tabled
    private static let emailSalt = "family-medical-app-email-salt-v1"

    /// Default API base URL - force unwrap is safe for hardcoded valid URL
    private static let defaultBaseURL =
        URL(string: "https://family-medical.cynexia.com/api/auth")! // swiftlint:disable:this force_unwrapping

    init(
        baseURL: URL = EmailVerificationService.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Hash email for zero-knowledge server lookup
    ///
    /// The server never sees the actual email address, only a salted hash.
    /// This provides privacy while still allowing the server to track
    /// verification attempts and identify returning users.
    ///
    /// - Parameter email: The email address to hash
    /// - Returns: 64-character lowercase hex string (SHA256)
    func hashEmail(_ email: String) -> String {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        let combined = normalized + Self.emailSalt
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func sendVerificationCode(to email: String) async throws {
        // Bypass for test emails in DEBUG builds or UI testing mode
        if Self.shouldBypassForTestEmail(email) { return }

        let url = baseURL.appendingPathComponent("send-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Send both email (for sending verification code) and hash (for server-side lookup)
        let body: [String: String] = [
            "email_hash": hashEmail(email),
            "email": email
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.emailVerificationFailed
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 429:
            throw AuthenticationError.tooManyVerificationAttempts
        default:
            throw AuthenticationError.emailVerificationFailed
        }
    }

    func verifyCode(_ code: String, for email: String) async throws -> EmailVerificationResult {
        // Bypass for test emails in DEBUG builds or UI testing mode
        if Self.shouldBypassForTestEmail(email) {
            return EmailVerificationResult(isValid: true, isReturningUser: false)
        }

        let url = baseURL.appendingPathComponent("verify-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email_hash": hashEmail(email),
            "code": code
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.emailVerificationFailed
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            let result = try JSONDecoder().decode(VerifyCodeResponse.self, from: data)
            return EmailVerificationResult(
                isValid: result.success,
                isReturningUser: result.isReturningUser
            )
        case 400:
            throw AuthenticationError.invalidVerificationCode
        case 410:
            throw AuthenticationError.verificationCodeExpired
        default:
            throw AuthenticationError.emailVerificationFailed
        }
    }

    /// Check if test email bypass should be used
    /// Bypass is enabled in DEBUG builds OR when running UI tests
    /// This ensures test emails work both during development and automated UI testing
    private static func shouldBypassForTestEmail(_ email: String) -> Bool {
        // Check if this is a recognized test email pattern
        let normalized = email.lowercased()
        let isTestEmail = normalized == "test@example.com" || normalized.hasSuffix("@test.example.com")

        guard isTestEmail else { return false }

        // Allow bypass in DEBUG builds or UI testing mode
        #if DEBUG
        return true
        #else
        return UITestingHelpers.isUITesting
        #endif
    }
}

// MARK: - Response Models

/// Response from verify-code endpoint
private struct VerifyCodeResponse: Decodable {
    let success: Bool
    let isReturningUser: Bool

    enum CodingKeys: String, CodingKey {
        case success
        case isReturningUser = "is_returning_user"
    }
}
