import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ObservationComponent Tests")
struct ObservationComponentTests {
    @Test("Round-trips single component")
    func roundTrip() throws {
        let component = ObservationComponent(name: "Systolic", value: 120.0, unit: "mmHg")
        let data = try JSONEncoder().encode(component)
        let decoded = try JSONDecoder().decode(ObservationComponent.self, from: data)
        #expect(decoded == component)
    }

    @Test("Round-trips array of components")
    func multipleComponentsRoundTrip() throws {
        let components = [
            ObservationComponent(name: "Systolic", value: 120.0, unit: "mmHg"),
            ObservationComponent(name: "Diastolic", value: 80.0, unit: "mmHg")
        ]
        let data = try JSONEncoder().encode(components)
        let decoded = try JSONDecoder().decode([ObservationComponent].self, from: data)
        #expect(decoded == components)
    }
}
