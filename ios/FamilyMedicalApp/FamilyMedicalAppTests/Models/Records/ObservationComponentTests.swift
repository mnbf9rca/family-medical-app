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

    @Test("id survives JSON round-trip")
    func idRoundTrips() throws {
        let original = ObservationComponent(name: "Weight", value: 70.0, unit: "kg")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ObservationComponent.self, from: data)
        #expect(decoded.id == original.id)
    }

    @Test("Distinct instances with same content have different ids")
    func distinctInstancesHaveDistinctIds() {
        let first = ObservationComponent(name: "Weight", value: 70, unit: "kg")
        let second = ObservationComponent(name: "Weight", value: 70, unit: "kg")
        #expect(first.id != second.id)
        #expect(first != second)
    }
}
