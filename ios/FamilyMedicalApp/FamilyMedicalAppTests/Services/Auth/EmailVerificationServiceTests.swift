import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct EmailVerificationServiceTests {
    // Use default URL - test emails bypass actual API calls anyway
    let sut = EmailVerificationService()

    // MARK: - Test Email Bypass (DEBUG only)

    #if DEBUG
    @Test
    func sendCodeBypassesForTestEmail() async throws {
        // Should not throw for test emails
        try await sut.sendVerificationCode(to: "test@example.com")
    }

    @Test
    func sendCodeBypassesForTestDomain() async throws {
        // Should not throw for test domain
        try await sut.sendVerificationCode(to: "user@test.example.com")
    }

    @Test
    func verifyCodeReturnsValidForTestEmail() async throws {
        let result = try await sut.verifyCode("123456", for: "test@example.com")
        #expect(result.isValid == true)
    }

    @Test
    func verifyCodeReturnsValidForTestDomain() async throws {
        let result = try await sut.verifyCode("000000", for: "anyone@test.example.com")
        #expect(result.isValid == true)
    }

    @Test
    func emailIsCaseInsensitive() async throws {
        // Should not throw for case variations
        try await sut.sendVerificationCode(to: "TEST@EXAMPLE.COM")
        try await sut.sendVerificationCode(to: "Test@Example.Com")
    }
    #endif

    // MARK: - Email Hashing

    @Test
    func hashEmailProducesDeterministicResult() {
        let hash1 = sut.hashEmail("test@example.com")
        let hash2 = sut.hashEmail("test@example.com")
        #expect(hash1 == hash2)
    }

    @Test
    func hashEmailIsCaseInsensitive() {
        let hash1 = sut.hashEmail("Test@Example.com")
        let hash2 = sut.hashEmail("test@example.com")
        #expect(hash1 == hash2)
    }

    @Test
    func hashEmailTrimsWhitespace() {
        let hash1 = sut.hashEmail("  test@example.com  ")
        let hash2 = sut.hashEmail("test@example.com")
        #expect(hash1 == hash2)
    }

    @Test
    func hashEmailProduces64CharHexString() {
        let hash = sut.hashEmail("test@example.com")
        // SHA256 produces 32 bytes = 64 hex characters
        #expect(hash.count == 64)
        let allHex = hash.allSatisfy(\.isHexDigit)
        #expect(allHex)
    }

    @Test
    func differentEmailsProduceDifferentHashes() {
        let hash1 = sut.hashEmail("user1@example.com")
        let hash2 = sut.hashEmail("user2@example.com")
        #expect(hash1 != hash2)
    }
}
