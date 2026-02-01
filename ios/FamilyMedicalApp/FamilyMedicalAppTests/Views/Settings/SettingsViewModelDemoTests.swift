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
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        #expect(viewModel.isDemoMode == true)
    }

    // MARK: - Exit Demo Mode Tests

    @Test("exitDemoMode calls demo service and shows confirmation pending")
    @MainActor
    func showExitDemoConfirmationSetsFlag() async throws {
        let demoService = MockDemoModeService()
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        viewModel.showExitDemoConfirmation()

        #expect(viewModel.showingExitDemoConfirmation == true)
    }

    @Test("cancelExitDemo clears confirmation flag")
    @MainActor
    func cancelExitDemoClearsFlag() async throws {
        let demoService = MockDemoModeService()
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        viewModel.showExitDemoConfirmation()

        viewModel.cancelExitDemo()

        #expect(viewModel.showingExitDemoConfirmation == false)
    }

    @Test("confirmExitDemo calls demo service exitDemoMode")
    @MainActor
    func confirmExitDemoCallsService() async throws {
        let demoService = MockDemoModeService()
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        viewModel.showExitDemoConfirmation()

        await viewModel.confirmExitDemo()

        #expect(demoService.exitDemoModeCalled == true)
        #expect(viewModel.showingExitDemoConfirmation == false)
    }

    @Test("confirmExitDemo sets demoModeExited flag")
    @MainActor
    func confirmExitDemoSetsExitedFlag() async throws {
        let demoService = MockDemoModeService()
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)

        await viewModel.confirmExitDemo()

        #expect(viewModel.demoModeExited == true)
    }

    @Test("isDemoMode returns false after exiting demo mode")
    @MainActor
    func isDemoModeFalseAfterExit() async throws {
        let demoService = MockDemoModeService()
        try await demoService.enterDemoMode()
        let viewModel = makeViewModel(demoModeService: demoService)
        #expect(viewModel.isDemoMode == true)

        await viewModel.confirmExitDemo()

        #expect(viewModel.isDemoMode == false)
    }
}
