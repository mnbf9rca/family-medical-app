import Testing
@testable import FamilyMedicalApp

/// Tests verifying that passphrase bytes are securely zeroed after authentication operations.
/// These tests validate RFC 9807 Section 4.1 compliance.
struct PasswordZeroingTests {
    /// Test that passphrase bytes are zeroed after setUp
    @Test
    func passphraseBytesAreZeroedAfterSetUp() async throws {
        // Given
        var passphraseBytes: [UInt8] = Array("test-password-123".utf8)
        let originalBytes = passphraseBytes // Copy for comparison

        // Create mock services
        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.setUp(
            passphraseBytes: &passphraseBytes,
            username: "testuser",
            enableBiometric: false
        )

        // Then - bytes should be zeroed
        #expect(passphraseBytes.allSatisfy { $0 == 0 }, "Passphrase bytes should be zeroed after setUp")
        #expect(passphraseBytes != originalBytes, "Bytes should have changed")
    }

    /// Test that passphrase bytes are zeroed after loginAndSetup
    @Test
    func passphraseBytesAreZeroedAfterLoginAndSetup() async throws {
        // Given
        var passphraseBytes: [UInt8] = Array("test-password-123".utf8)

        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.loginAndSetup(
            passphraseBytes: &passphraseBytes,
            username: "testuser",
            enableBiometric: false
        )

        // Then
        #expect(passphraseBytes.allSatisfy { $0 == 0 }, "Passphrase bytes should be zeroed after loginAndSetup")
    }

    /// Test that passphrase bytes are zeroed after unlock
    @Test
    func passphraseBytesAreZeroedAfterUnlock() async throws {
        // Given
        var passphraseBytes: [UInt8] = Array("test-password-123".utf8)

        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.unlockWithPassphrase(&passphraseBytes)

        // Then
        #expect(passphraseBytes.allSatisfy { $0 == 0 }, "Passphrase bytes should be zeroed after unlock")
    }
}
