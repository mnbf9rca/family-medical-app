import Foundation
@testable import FamilyMedicalApp

final class FakeThermalStateProvider: ThermalStateProviding, @unchecked Sendable {
    var thermalState: ProcessInfo.ThermalState = .nominal
    private var handler: (@Sendable (ProcessInfo.ThermalState) -> Void)?

    func addObserver(
        _ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void
    ) -> NSObjectProtocol {
        self.handler = handler
        return NSObject()
    }

    /// Test hook: simulate a thermal-state change firing.
    func simulateThermalChange(_ newState: ProcessInfo.ThermalState) {
        thermalState = newState
        handler?(newState)
    }
}
