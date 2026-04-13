import Foundation
@testable import FamilyMedicalApp

final class FakeThermalStateProvider: ThermalStateProviding, @unchecked Sendable {
    var thermalState: ProcessInfo.ThermalState = .nominal
    private var handler: (@Sendable (ProcessInfo.ThermalState) -> Void)?
    private(set) var addObserverCallCount: Int = 0

    func addObserver(
        _ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void
    ) -> NSObjectProtocol {
        addObserverCallCount += 1
        self.handler = handler
        return NSObject()
    }

    /// Test hook: simulate a thermal-state change firing.
    func simulateThermalChange(_ newState: ProcessInfo.ThermalState) {
        thermalState = newState
        handler?(newState)
    }
}
