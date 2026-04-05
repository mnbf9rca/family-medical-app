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

    /// Custom decoder: auto-generate an id if absent. Lets pre-existing JSON payloads
    /// (and hand-written test fixtures) decode without requiring an id field. The
    /// generated id is stable for the decoded instance's lifetime; callers that care
    /// about durable identity must ensure the id is persisted on subsequent encodes
    /// (it always is — `encode(to:)` uses synthesised behaviour which emits `id`).
    private enum CodingKeys: String, CodingKey {
        case id, name, value, unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(String.self, forKey: .unit)
    }
}
