import Testing
@testable import FamilyMedicalApp

@Suite("RecordTypeRegistry Tests")
struct RecordTypeRegistryTests {
    private let registry = RecordTypeRegistry()

    @Test
    func allRecordTypesReturnsAllCases() {
        #expect(registry.allRecordTypes == RecordType.allCases)
    }

    @Test(arguments: RecordType.allCases)
    func displayNameReturnsNonEmpty(_ type: RecordType) {
        let name = registry.displayName(for: type)
        #expect(!name.isEmpty, "displayName for \(type) should not be empty")
    }

    @Test(arguments: RecordType.allCases)
    func iconSystemNameReturnsNonEmpty(_ type: RecordType) {
        let icon = registry.iconSystemName(for: type)
        #expect(!icon.isEmpty, "iconSystemName for \(type) should not be empty")
    }

    @Test(arguments: RecordType.allCases)
    func fieldMetadataReturnsNonEmpty(_ type: RecordType) {
        let metadata = registry.fieldMetadata(for: type)
        #expect(!metadata.isEmpty, "fieldMetadata for \(type) should not be empty")
    }

    @Test
    func recordTypeDisplayProperties() {
        #expect(RecordType.immunization.displayName == "Immunization")
        #expect(RecordType.immunization.iconSystemName == "syringe")
        #expect(RecordType.medicationStatement.displayName == "Medication")
        #expect(RecordType.clinicalNote.displayName == "Note")
    }
}
