import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel demo mode functionality
@MainActor
struct AuthenticationViewModelDemoTests {
    // MARK: - Demo Mode Tests

    @Test
    func selectDemoTransitionsToDemoState() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.selectDemo()

        #expect(viewModel.flowState == .demo)
    }

    @Test
    func selectDemoClearsErrorMessage() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.errorMessage = "Some error"

        viewModel.selectDemo()

        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func enterDemoModeSetsIsAuthenticatedTrue() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()

        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func enterDemoModeSetsFlowStateToAuthenticated() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()

        #expect(viewModel.flowState == .authenticated)
    }

    @Test
    func enterDemoModeCallsDemoModeService() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()

        #expect(mockDemoModeService.enterDemoModeCalled == true)
    }

    @Test
    func enterDemoModeFailureShowsError() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        mockDemoModeService.shouldFailEnter = true
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.flowState == .welcome)
    }

    @Test
    func exitDemoModeResetsToWelcome() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()
        await viewModel.exitDemoMode()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.flowState == .welcome)
    }

    @Test
    func exitDemoModeCallsDemoModeService() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let mockDemoModeService = MockDemoModeService()
        let viewModel = AuthenticationViewModel(
            authService: authService,
            demoModeService: mockDemoModeService
        )

        await viewModel.enterDemoMode()
        await viewModel.exitDemoMode()

        #expect(mockDemoModeService.exitDemoModeCalled == true)
    }
}
