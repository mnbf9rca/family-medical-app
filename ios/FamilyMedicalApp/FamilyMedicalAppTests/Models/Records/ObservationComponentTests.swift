import XCTest
@testable import FamilyMedicalApp

final class ObservationComponentTests: XCTestCase {
    func testRoundTrip() throws {
        let component = ObservationComponent(name: "Systolic", value: 120.0, unit: "mmHg")
        let data = try JSONEncoder().encode(component)
        let decoded = try JSONDecoder().decode(ObservationComponent.self, from: data)
        XCTAssertEqual(decoded, component)
    }

    func testMultipleComponentsRoundTrip() throws {
        let components = [
            ObservationComponent(name: "Systolic", value: 120.0, unit: "mmHg"),
            ObservationComponent(name: "Diastolic", value: 80.0, unit: "mmHg")
        ]
        let data = try JSONEncoder().encode(components)
        let decoded = try JSONDecoder().decode([ObservationComponent].self, from: data)
        XCTAssertEqual(decoded, components)
    }
}
