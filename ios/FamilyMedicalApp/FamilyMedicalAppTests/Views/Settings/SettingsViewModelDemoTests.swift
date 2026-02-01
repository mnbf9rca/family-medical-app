import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("SettingsViewModel Demo Mode Tests")
struct SettingsViewModelDemoTests {
    // MARK: - Test Setup

    @MainActor
    func makeViewModel(
        exportService: MockExportService = MockExportService(),
        importService: MockImportService = MockImportService(),
        backupFileService: MockBackupFileService = MockBackupFileService(),
        demoModeService: MockDemoModeService = MockDemoModeService()
    ) -> SettingsViewModel {
        SettingsViewModel(
            exportService: exportService,
            importService: importService,
            backupFileService: backupFileService,
            demoModeService: demoModeService
        )
    }

    // MARK: - Demo Mode Indicator Tests

    @Test("isDemoMode returns false when not in demo mode")
    @MainActor
    func isDemoModeFalseByDefault() {
        let demoService = MockDemoModeService()
        let viewModel = makeViewModel(demoModeService: demoService)

        #expect(viewModel.isDemoMode == false)
    }

    @Test("isDemoMode returns true when in demo mode")
    @MainActor
    func isDemoModeTrueWhenActive() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        #expect(viewModel.isDemoMode == true)
    }

    // MARK: - Exit Demo Mode Tests

    @Test("exitDemoMode calls demo service and shows confirmation pending")
    @MainActor
    func showExitDemoConfirmationSetsFlag() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        viewModel.showExitDemoConfirmation()

        #expect(viewModel.showingExitDemoConfirmation == true)
    }

    @Test("cancelExitDemo clears confirmation flag")
    @MainActor
    func cancelExitDemoClearsFlag() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        viewModel.showExitDemoConfirmation()

        viewModel.cancelExitDemo()

        #expect(viewModel.showingExitDemoConfirmation == false)
    }

    @Test("confirmExitDemo posts notification and clears confirmation flag")
    @MainActor
    func confirmExitDemoPostsNotification() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        viewModel.showExitDemoConfirmation()

        // Track if notification is posted using nonisolated(unsafe) since observer runs on main queue
        // and we await on MainActor before checking - safe in this test context
        nonisolated(unsafe) var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .demoModeExitRequested,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await viewModel.confirmExitDemo()

        #expect(notificationReceived == true)
        #expect(viewModel.showingExitDemoConfirmation == false)
        // Note: Service is NOT called directly - AuthenticationViewModel handles it via notification
        #expect(demoService.exitDemoModeCalled == false)
    }

    @Test("confirmExitDemo sets demoModeExited flag")
    @MainActor
    func confirmExitDemoSetsExitedFlag() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        await viewModel.confirmExitDemo()

        #expect(viewModel.demoModeExited == true)
    }

    @Test("isDemoMode unchanged by confirmExitDemo - service handles via notification")
    @MainActor
    func isDemoModeUnchangedByConfirmExitDemo() async throws {
        let demoService = MockDemoModeService()
        _ = try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        #expect(viewModel.isDemoMode == true)

        await viewModel.confirmExitDemo()

        // isDemoMode is still true because confirmExitDemo only posts notification
        // AuthenticationViewModel.exitDemoMode() handles the actual service call
        #expect(viewModel.isDemoMode == true)
        #expect(viewModel.demoModeExited == true)
    }
}
