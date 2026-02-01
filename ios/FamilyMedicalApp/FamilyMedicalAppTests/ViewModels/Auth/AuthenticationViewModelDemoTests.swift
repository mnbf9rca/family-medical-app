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

    // MARK: - Helper

    private func makeViewModel(
        mockDemoModeService: MockDemoModeService = MockDemoModeService(),
        mockDemoDataSeeder: MockDemoDataSeeder = MockDemoDataSeeder()
    ) -> AuthenticationViewModel {
        AuthenticationViewModel(
            authService: MockAuthenticationService(isSetUp: false),
            demoModeService: mockDemoModeService,
            demoDataSeeder: mockDemoDataSeeder
        )
    }

    @Test
    func enterDemoModeSetsIsAuthenticatedTrue() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()

        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func enterDemoModeSetsFlowStateToAuthenticated() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()

        #expect(viewModel.flowState == .authenticated)
    }

    @Test
    func enterDemoModeCallsDemoModeService() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()

        #expect(mockDemoModeService.enterDemoModeCalled == true)
    }

    @Test
    func enterDemoModeSeedsDemoData() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()

        #expect(mockDemoDataSeeder.seedDemoDataCalled == true)
    }

    @Test
    func enterDemoModeFailureShowsError() async {
        let mockDemoModeService = MockDemoModeService()
        mockDemoModeService.shouldFailEnter = true
        let viewModel = makeViewModel(mockDemoModeService: mockDemoModeService)

        await viewModel.enterDemoMode()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.flowState == .welcome)
    }

    @Test
    func exitDemoModeResetsToWelcome() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()
        await viewModel.exitDemoMode()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.flowState == .welcome)
    }

    @Test
    func exitDemoModeCallsDemoModeService() async {
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        await viewModel.enterDemoMode()
        await viewModel.exitDemoMode()

        #expect(mockDemoModeService.exitDemoModeCalled == true)
    }

    // MARK: - Integration Tests

    @Test("Complete demo flow from welcome to exit")
    func completeDemoFlowFromWelcomeToExit() async {
        // Setup
        let mockDemoModeService = MockDemoModeService()
        let mockDemoDataSeeder = MockDemoDataSeeder()
        let viewModel = makeViewModel(
            mockDemoModeService: mockDemoModeService,
            mockDemoDataSeeder: mockDemoDataSeeder
        )

        // 1. Start at welcome
        #expect(viewModel.flowState == .welcome)
        #expect(viewModel.isAuthenticated == false)

        // 2. Select demo - transitions to demo loading state
        viewModel.selectDemo()
        #expect(viewModel.flowState == .demo)

        // 3. Enter demo mode - creates demo account
        await viewModel.enterDemoMode()
        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.flowState == .authenticated)
        #expect(mockDemoModeService.isInDemoMode == true)
        #expect(mockDemoDataSeeder.seedDemoDataCalled == true)

        // 4. Exit demo mode - cleans up and returns to welcome
        await viewModel.exitDemoMode()
        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.flowState == .welcome)
        #expect(mockDemoModeService.isInDemoMode == false)
    }
}
