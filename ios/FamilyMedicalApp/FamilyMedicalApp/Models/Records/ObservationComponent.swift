import Foundation

/// A single measured value within an Observation (e.g., systolic BP, weight).
/// Most observations have one component. Blood pressure has two (systolic + diastolic).
///
/// Each instance has a stable `id: UUID` so SwiftUI's `ForEach` can identify rows
/// by identity rather than position. This matters for the component-editor UI:
/// when a middle row is deleted, SwiftUI destroys the right view (animations are
/// correct, per-row `@State` doesn't drift to the wrong row).
struct ObservationComponent: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let unit: String

    init(id: UUID = UUID(), name: String, value: Double, unit: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
    }
}
