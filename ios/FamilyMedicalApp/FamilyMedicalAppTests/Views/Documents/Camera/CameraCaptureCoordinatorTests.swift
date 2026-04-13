import AVFoundation
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import FamilyMedicalApp

@MainActor
struct CameraCaptureCoordinatorTests {
    // MARK: - Fixtures

    struct TestFixtures {
        let coordinator: CameraCaptureCoordinator
        let auth: FakeAuthorizationStatusProvider
        let capturer: FakePhotoCapturing
        let thermal: FakeThermalStateProvider
        let session: FakeSessionController
    }

    func makeFixtures(
        authStatus: AVAuthorizationStatus = .authorized,
        accessGranted: Bool = true,
        cameraAvailable: Bool = true
    ) -> TestFixtures {
        let auth = FakeAuthorizationStatusProvider(
            initialStatus: authStatus,
            accessGranted: accessGranted
        )
        let capturer = FakePhotoCapturing()
        let thermal = FakeThermalStateProvider()
        let session = FakeSessionController()
        let coordinator = CameraCaptureCoordinator(
            auth: auth,
            capturer: capturer,
            thermal: thermal,
            session: session
        ) { cameraAvailable }
        return TestFixtures(
            coordinator: coordinator,
            auth: auth,
            capturer: capturer,
            thermal: thermal,
            session: session
        )
    }

    // MARK: - Initial State

    @Test
    func initialState_beforeStart_isNotDetermined() {
        let fixtures = makeFixtures(authStatus: .notDetermined)
        if case .notDetermined = fixtures.coordinator.state {} else {
            Issue.record("Expected .notDetermined, got \(fixtures.coordinator.state)")
        }
    }

    @Test
    func initialState_denied_isPermissionDenied() {
        let fixtures = makeFixtures(authStatus: .denied)
        if case .permissionDenied = fixtures.coordinator.state {} else {
            Issue.record("Expected .permissionDenied")
        }
    }

    @Test
    func initialState_restricted_isPermissionDenied() {
        let fixtures = makeFixtures(authStatus: .restricted)
        if case .permissionDenied = fixtures.coordinator.state {} else {
            Issue.record("Expected .permissionDenied for .restricted")
        }
    }

    @Test
    func initialState_authorizedNoCamera_isCameraUnavailable() {
        let fixtures = makeFixtures(authStatus: .authorized, cameraAvailable: false)
        if case .cameraUnavailable = fixtures.coordinator.state {} else {
            Issue.record("Expected .cameraUnavailable")
        }
    }

    @Test
    func initialState_authorizedWithCamera_isRunning() {
        let fixtures = makeFixtures(authStatus: .authorized, cameraAvailable: true)
        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running")
        }
    }

    // MARK: - start()

    @Test
    func start_fromNotDetermined_granted_transitionsToRunning() async {
        let fixtures = makeFixtures(authStatus: .notDetermined, accessGranted: true)

        await fixtures.coordinator.start()

        #expect(fixtures.auth.requestAccessCalls == 1)
        #expect(fixtures.session.startCalls == 1)
        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running after grant, got \(fixtures.coordinator.state)")
        }
    }

    @Test
    func start_fromNotDetermined_denied_transitionsToPermissionDenied() async {
        let fixtures = makeFixtures(authStatus: .notDetermined, accessGranted: false)

        await fixtures.coordinator.start()

        #expect(fixtures.auth.requestAccessCalls == 1)
        #expect(fixtures.session.startCalls == 0)
        if case .permissionDenied = fixtures.coordinator.state {} else {
            Issue.record("Expected .permissionDenied after deny")
        }
    }

    @Test
    func start_fromAuthorizedWithCamera_startsSessionImmediately() async {
        let fixtures = makeFixtures(authStatus: .authorized, cameraAvailable: true)

        await fixtures.coordinator.start()

        #expect(fixtures.auth.requestAccessCalls == 0) // already authorized
        #expect(fixtures.session.startCalls == 1)
        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running")
        }
    }

    @Test
    func start_fromCameraUnavailable_doesNotStartSession() async {
        let fixtures = makeFixtures(authStatus: .authorized, cameraAvailable: false)

        await fixtures.coordinator.start()

        #expect(fixtures.session.startCalls == 0)
    }

    @Test
    func start_fromDenied_doesNotStartSession() async {
        let fixtures = makeFixtures(authStatus: .denied)

        await fixtures.coordinator.start()

        #expect(fixtures.auth.requestAccessCalls == 0)
        #expect(fixtures.session.startCalls == 0)
        if case .permissionDenied = fixtures.coordinator.state {} else {
            Issue.record("Expected .permissionDenied")
        }
    }
}
