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
        coordinator.observeThermalState()
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

    // MARK: - handlePhoto — byte integrity

    @Test
    func handlePhoto_heicBytes_transitionsToCapturedWithExactBytes() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        let heic = SyntheticPhotoFixtures.heicData()
        let photo = FakeCapturedPhoto(fileData: heic, uniformType: .heic)

        fixtures.coordinator.handlePhoto(photo)

        guard case let .captured(data, type) = fixtures.coordinator.state else {
            Issue.record("Expected .captured, got \(fixtures.coordinator.state)")
            return
        }
        #expect(data == heic) // byte-for-byte equality — the invariant
        #expect(data.count == heic.count)
        #expect(type == .heic)
    }

    @Test
    func handlePhoto_jpegBytes_transitionsToCapturedWithExactBytes() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        let jpeg = SyntheticPhotoFixtures.jpegData()
        let photo = FakeCapturedPhoto(fileData: jpeg, uniformType: .jpeg)

        fixtures.coordinator.handlePhoto(photo)

        guard case let .captured(data, type) = fixtures.coordinator.state else {
            Issue.record("Expected .captured")
            return
        }
        #expect(data == jpeg)
        #expect(type == .jpeg)
    }

    @Test
    func handlePhoto_nilData_transitionsToFailed() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        let photo = FakeCapturedPhoto(fileData: nil, uniformType: .jpeg)
        fixtures.coordinator.handlePhoto(photo)

        if case .failed = fixtures.coordinator.state {} else {
            Issue.record("Expected .failed when fileData is nil")
        }
    }

    @Test
    func capturePhoto_fromRunning_transitionsToCapturingAndCalls() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.coordinator.capturePhoto()

        #expect(fixtures.capturer.captureCalls == 1)
        if case .capturing = fixtures.coordinator.state {} else {
            Issue.record("Expected .capturing")
        }
    }

    @Test
    func capturePhoto_fromNonRunning_isNoOp() {
        let fixtures = makeFixtures(authStatus: .notDetermined)

        fixtures.coordinator.capturePhoto()

        #expect(fixtures.capturer.captureCalls == 0)
        if case .notDetermined = fixtures.coordinator.state {} else {
            Issue.record("Expected state unchanged")
        }
    }

    // MARK: - retake / confirm / flipCamera

    @Test
    func retake_fromCaptured_transitionsToRunning() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()
        fixtures.coordinator.handlePhoto(
            FakeCapturedPhoto(fileData: SyntheticPhotoFixtures.jpegData(), uniformType: .jpeg)
        )

        fixtures.coordinator.retake()

        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running after retake")
        }
    }

    @Test
    func retake_fromRunning_isNoOp() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.coordinator.retake()

        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running (retake from running is a no-op)")
        }
    }

    @Test
    func confirm_fromCaptured_yieldsDataAndType() async throws {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()
        let heic = SyntheticPhotoFixtures.heicData()
        fixtures.coordinator.handlePhoto(FakeCapturedPhoto(fileData: heic, uniformType: .heic))

        let confirmed = try #require(fixtures.coordinator.confirm())

        #expect(confirmed.0 == heic)
        #expect(confirmed.1 == .heic)
    }

    @Test
    func confirm_fromRunning_returnsNil() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        #expect(fixtures.coordinator.confirm() == nil)
    }

    @Test
    func flipCamera_fromRunning_callsSessionSwap() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.coordinator.flipCamera()

        #expect(fixtures.session.swapCameraPositionCalls == 1)
    }

    @Test
    func flipCamera_fromCaptured_isNoOp() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()
        fixtures.coordinator.handlePhoto(
            FakeCapturedPhoto(fileData: SyntheticPhotoFixtures.jpegData(), uniformType: .jpeg)
        )

        fixtures.coordinator.flipCamera()

        #expect(fixtures.session.swapCameraPositionCalls == 0)
    }

    // MARK: - Interruption and runtime

    @Test
    func handleInterruption_fromRunning_transitionsToInterrupted() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.coordinator.handleInterruption(began: true)

        if case .interrupted = fixtures.coordinator.state {} else {
            Issue.record("Expected .interrupted")
        }
    }

    @Test
    func handleInterruption_ended_transitionsBackToRunning() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()
        fixtures.coordinator.handleInterruption(began: true)

        fixtures.coordinator.handleInterruption(began: false)

        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running after interruption end")
        }
    }

    @Test
    func handleInterruption_beganFromNonRunning_isNoOp() {
        let fixtures = makeFixtures(authStatus: .notDetermined)

        fixtures.coordinator.handleInterruption(began: true)

        if case .notDetermined = fixtures.coordinator.state {} else {
            Issue.record("Expected .notDetermined unchanged")
        }
    }

    @Test
    func handleInterruption_endedFromNonInterrupted_isNoOp() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.coordinator.handleInterruption(began: false)

        if case .running = fixtures.coordinator.state {} else {
            Issue.record("Expected .running unchanged")
        }
    }

    @Test
    func handleRuntimeError_transitionsToFailed() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        struct StubError: Error {}
        fixtures.coordinator.handleRuntimeError(StubError())

        if case .failed = fixtures.coordinator.state {} else {
            Issue.record("Expected .failed")
        }
    }

    // MARK: - Thermal state

    @Test
    func thermalStateSerious_setsDegradedFlag() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()

        fixtures.thermal.simulateThermalChange(.serious)
        // Let the main-actor observer task run.
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(fixtures.coordinator.isQualityDegraded == true)
    }

    @Test
    func thermalStateNominal_clearsDegradedFlag() async {
        let fixtures = makeFixtures()
        await fixtures.coordinator.start()
        fixtures.thermal.simulateThermalChange(.serious)
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        fixtures.thermal.simulateThermalChange(.nominal)
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(fixtures.coordinator.isQualityDegraded == false)
    }
}
