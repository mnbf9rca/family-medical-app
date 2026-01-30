import Testing
@testable import FamilyMedicalApp

/// Tests verifying that password bytes are securely zeroed after authentication operations.
/// These tests validate RFC 9807 Section 4.1 compliance.
struct PasswordZeroingTests {
    /// Test that password bytes are zeroed after setUp
    @Test
    func passwordBytesAreZeroedAfterSetUp() async throws {
        // Given
        var passwordBytes: [UInt8] = Array("test-password-123".utf8)
        let originalBytes = passwordBytes // Copy for comparison

        // Create mock services
        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.setUp(
            passwordBytes: &passwordBytes,
            username: "testuser",
            enableBiometric: false
        )

        // Then - bytes should be zeroed
        #expect(passwordBytes.allSatisfy { $0 == 0 }, "Password bytes should be zeroed after setUp")
        #expect(passwordBytes != originalBytes, "Bytes should have changed")
    }

    /// Test that password bytes are zeroed after loginAndSetup
    @Test
    func passwordBytesAreZeroedAfterLoginAndSetup() async throws {
        // Given
        var passwordBytes: [UInt8] = Array("test-password-123".utf8)

        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.loginAndSetup(
            passwordBytes: &passwordBytes,
            username: "testuser",
            enableBiometric: false
        )

        // Then
        #expect(passwordBytes.allSatisfy { $0 == 0 }, "Password bytes should be zeroed after loginAndSetup")
    }

    /// Test that password bytes are zeroed after unlock
    @Test
    func passwordBytesAreZeroedAfterUnlock() async throws {
        // Given
        var passwordBytes: [UInt8] = Array("test-password-123".utf8)

        let mockAuth = MockAuthenticationService()

        // When
        try await mockAuth.unlockWithPassword(&passwordBytes)

        // Then
        #expect(passwordBytes.allSatisfy { $0 == 0 }, "Password bytes should be zeroed after unlock")
    }
}
