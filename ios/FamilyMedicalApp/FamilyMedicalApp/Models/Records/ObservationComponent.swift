import Foundation

/// A single measured value within an Observation (e.g., systolic BP, weight).
/// Most observations have one component. Blood pressure has two (systolic + diastolic).
struct ObservationComponent: Codable, Sendable, Equatable {
    let name: String
    let value: Double
    let unit: String
}
