import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationCoordinatorView rendering and navigation logic
@MainActor
struct AuthenticationCoordinatorViewTests {
    // MARK: - View Body Tests

    @Test
    func coordinatorRendersSetupView() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func coordinatorRendersUnlockView() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = false

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func coordinatorRendersMainApp() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func coordinatorRendersMainAppWithLock() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body multiple times to exercise different states
        _ = view.body

        // Simulate lock action
        viewModel.lock()
        _ = view.body
    }

    @Test
    func coordinatorRendersMainAppWithLogout() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body
        _ = view.body

        // Simulate logout
        await viewModel.logout()
        _ = view.body
    }

    // MARK: - Scene Phase Tests

    @Test
    func handleScenePhase_backgroundRecordsTime() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Transition to background
        view.handleScenePhaseChange(oldPhase: .active, newPhase: .background)

        // Verify recordBackgroundTime was called
        #expect(lockStateService.recordBackgroundTimeCalled)
    }

    @Test
    func handleScenePhase_inactiveRecordsTime() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Transition to inactive
        view.handleScenePhaseChange(oldPhase: .active, newPhase: .inactive)

        // Verify recordBackgroundTime was called
        #expect(lockStateService.recordBackgroundTimeCalled)
    }

    @Test
    func handleScenePhase_notAuthenticatedNoRecord() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = false

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Transition to background when not authenticated
        view.handleScenePhaseChange(oldPhase: .active, newPhase: .background)

        // Verify recordBackgroundTime was NOT called
        #expect(!lockStateService.recordBackgroundTimeCalled)
    }

    @Test
    func handleScenePhase_activeLocksWhenTimeout() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        lockStateService.shouldLockOnForegroundReturnValue = true

        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Transition to active when timeout reached
        view.handleScenePhaseChange(oldPhase: .background, newPhase: .active)

        // Verify the app is locked
        #expect(!viewModel.isAuthenticated)
    }

    @Test
    func handleScenePhase_activeNoLockWhenNoTimeout() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        lockStateService.shouldLockOnForegroundReturnValue = false

        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Transition to active when timeout not reached
        view.handleScenePhaseChange(oldPhase: .background, newPhase: .active)

        // Verify the app is still authenticated
        #expect(viewModel.isAuthenticated)
    }

    @Test
    func handleScenePhase_samePhaseTransitionIsNoOp() {
        let authService = MockAuthenticationService(isSetUp: true)
        let lockStateService = MockLockStateService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            lockStateService: lockStateService
        )
        viewModel.isAuthenticated = true

        let view = AuthenticationCoordinatorView(viewModel: viewModel)

        // Access body to ensure view is rendered
        _ = view.body

        // Test that transitioning to the same phase is a no-op
        // This verifies the switch statement handles all cases correctly
        view.handleScenePhaseChange(oldPhase: .active, newPhase: .active)

        // App should remain authenticated (no state change)
        #expect(viewModel.isAuthenticated)

        // Note: The @unknown default case in handleScenePhaseChange exists for
        // future Swift evolution, but cannot be tested with current ScenePhase cases
    }

    // MARK: - MainAppView Tests

    @Test
    func mainAppViewRendersWithToolbar() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = true

        let view = MainAppView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func mainAppViewLockAction() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = true

        let view = MainAppView(viewModel: viewModel)

        // Access body
        _ = view.body

        // Verify lock action works via viewModel
        viewModel.lock()
        #expect(!viewModel.isAuthenticated)
    }

    @Test
    func mainAppViewLogoutAction() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isAuthenticated = true

        let view = MainAppView(viewModel: viewModel)

        // Access body
        _ = view.body

        // Verify logout action works via viewModel
        await viewModel.logout()
        #expect(!viewModel.isAuthenticated)
    }
}
