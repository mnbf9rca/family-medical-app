import LocalAuthentication
import Testing
@testable import FamilyMedicalApp

@MainActor
struct BiometricServiceTests {
    // MARK: - Biometry Type Tests

    @Test
    func biometryTypeReturnsNoneWhenNotAvailable() {
        let context = MockLAContext(canEvaluate: false, biometryType: .none)
        let service = BiometricService(context: context)

        let type = service.biometryType
        #expect(type == .none)
    }

    @Test
    func biometryTypeReturnsFaceIDWhenAvailable() {
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID)
        let service = BiometricService(context: context)

        let type = service.biometryType
        #expect(type == .faceID)
    }

    @Test
    func biometryTypeReturnsTouchIDWhenAvailable() {
        let context = MockLAContext(canEvaluate: true, biometryType: .touchID)
        let service = BiometricService(context: context)

        let type = service.biometryType
        #expect(type == .touchID)
    }

    // MARK: - Availability Tests

    @Test
    func isBiometricAvailableReturnsTrueWhenAvailable() {
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID)
        let service = BiometricService(context: context)

        #expect(service.isBiometricAvailable == true)
    }

    @Test
    func isBiometricAvailableReturnsFalseWhenNotAvailable() {
        let context = MockLAContext(canEvaluate: false, biometryType: .none)
        let service = BiometricService(context: context)

        #expect(service.isBiometricAvailable == false)
    }

    // MARK: - Authentication Tests

    @Test
    func authenticateSucceedsWhenBiometricSucceeds() async throws {
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .success(true))
        let service = BiometricService(context: context)

        try await service.authenticate(reason: "Test authentication")
        // No error thrown means success
    }

    @Test
    func authenticateThrowsWhenBiometricNotAvailable() async {
        let context = MockLAContext(canEvaluate: false, biometryType: .none)
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricNotAvailable) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsCancelledWhenUserCancels() async {
        let error = LAError(.userCancel)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricCancelled) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsNotEnrolledWhenBiometryNotEnrolled() async {
        let context = MockLAContext(
            canEvaluate: false,
            biometryType: .none,
            evaluationError: LAError(.biometryNotEnrolled)
        )
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricNotEnrolled) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func biometryTypeReturnsNoneForUnknownType() {
        let context = MockLAContext(canEvaluate: true, biometryType: LABiometryType(rawValue: 999) ?? .none)
        let service = BiometricService(context: context)

        #expect(service.biometryType == .none)
    }

    @Test
    func authenticateThrowsWhenAuthenticationFails() async {
        let error = LAError(.authenticationFailed)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.self) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsWhenSystemCancels() async {
        let error = LAError(.systemCancel)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricCancelled) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsWhenAppCancels() async {
        let error = LAError(.appCancel)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricCancelled) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsNotAvailableWhenBiometryNotAvailableError() async {
        let error = LAError(.biometryNotAvailable)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricNotAvailable) {
            try await service.authenticate(reason: "Test")
        }
    }

    @Test
    func authenticateThrowsNotEnrolledFromAuthenticationError() async {
        let error = LAError(.biometryNotEnrolled)
        let context = MockLAContext(canEvaluate: true, biometryType: .faceID, authenticationResult: .failure(error))
        let service = BiometricService(context: context)

        await #expect(throws: AuthenticationError.biometricNotEnrolled) {
            try await service.authenticate(reason: "Test")
        }
    }
}

// MARK: - Mock LAContext

private class MockLAContext: LAContext {
    private let _canEvaluate: Bool
    private let _biometryType: LABiometryType
    private let _authenticationResult: Result<Bool, Error>?
    private let _evaluationError: Error?

    init(
        canEvaluate: Bool,
        biometryType: LABiometryType,
        authenticationResult: Result<Bool, Error>? = nil,
        evaluationError: Error? = nil
    ) {
        _canEvaluate = canEvaluate
        _biometryType = biometryType
        _authenticationResult = authenticationResult
        _evaluationError = evaluationError
        super.init()
    }

    override var biometryType: LABiometryType {
        _biometryType
    }

    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if let evaluationError = _evaluationError {
            error?.pointee = evaluationError as NSError
        }
        return _canEvaluate
    }

    override func evaluatePolicy(
        _ policy: LAPolicy,
        localizedReason: String
    ) async throws -> Bool {
        if let result = _authenticationResult {
            switch result {
            case let .success(value):
                return value
            case let .failure(error):
                throw error
            }
        }
        return true
    }
}
