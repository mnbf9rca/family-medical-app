import XCTest
@testable import FamilyMedicalApp

final class RecordTypeRegistryTests: XCTestCase {
    private let registry = RecordTypeRegistry()

    func testAllRecordTypesReturnsAllCases() {
        XCTAssertEqual(registry.allRecordTypes, RecordType.allCases)
    }

    func testDisplayNameReturnsNonEmpty() {
        for type in RecordType.allCases {
            let name = registry.displayName(for: type)
            XCTAssertFalse(name.isEmpty, "displayName for \(type) should not be empty")
        }
    }

    func testIconSystemNameReturnsNonEmpty() {
        for type in RecordType.allCases {
            let icon = registry.iconSystemName(for: type)
            XCTAssertFalse(icon.isEmpty, "iconSystemName for \(type) should not be empty")
        }
    }

    func testFieldMetadataReturnsNonEmpty() {
        for type in RecordType.allCases {
            let metadata = registry.fieldMetadata(for: type)
            XCTAssertFalse(metadata.isEmpty, "fieldMetadata for \(type) should not be empty")
        }
    }

    func testRecordTypeDisplayProperties() {
        XCTAssertEqual(RecordType.immunization.displayName, "Immunization")
        XCTAssertEqual(RecordType.immunization.iconSystemName, "syringe")
        XCTAssertEqual(RecordType.medicationStatement.displayName, "Medication")
        XCTAssertEqual(RecordType.clinicalNote.displayName, "Note")
    }
}
