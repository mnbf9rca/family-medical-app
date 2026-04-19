import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel scene phase delegation to LockStateService
/// Unit tests for the ViewModel's scene-phase delegation surface.
/// End-to-end scene-phase behaviour is covered by AuthenticationCoordinatorViewTests.
@MainActor
struct AuthenticationViewModelScenePhaseTests {
    @Test
    func onEnterBackgroundDelegatesToLockStateService() {
        let mockLockStateService = MockLockStateService()
        let sut = AuthenticationViewModel(lockStateService: mockLockStateService)

        sut.onEnterBackground()

        #expect(mockLockStateService.recordBackgroundTimeCalled)
    }

    @Test
    func shouldLockOnForegroundReflectsLockStateServiceTrue() {
        let mockLockStateService = MockLockStateService()
        mockLockStateService.shouldLockOnForegroundReturnValue = true
        let sut = AuthenticationViewModel(lockStateService: mockLockStateService)

        #expect(sut.shouldLockOnForeground == true)
    }

    @Test
    func shouldLockOnForegroundReflectsLockStateServiceFalse() {
        let mockLockStateService = MockLockStateService()
        mockLockStateService.shouldLockOnForegroundReturnValue = false
        let sut = AuthenticationViewModel(lockStateService: mockLockStateService)

        #expect(sut.shouldLockOnForeground == false)
    }
}
