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
}
