import Foundation
import Testing
@testable import FamilyMedicalApp

struct BuiltInSchemasTests {
    // MARK: - Vaccine Schema

    @Test
    func vaccineSchema_hasCorrectId() {
        let schema = BuiltInSchemas.schema(for: .vaccine)
        #expect(schema.id == "vaccine")
        #expect(schema.isBuiltIn)
    }

    @Test
    func vaccineSchema_hasRequiredFields() {
        let schema = BuiltInSchemas.schema(for: .vaccine)
        #expect(schema.field(withId: "vaccineName")?.isRequired == true)
        #expect(schema.field(withId: "dateAdministered")?.isRequired == true)
    }

    @Test
    func vaccineSchema_hasOptionalFields() {
        let schema = BuiltInSchemas.schema(for: .vaccine)
        #expect(schema.field(withId: "provider")?.isRequired == false)
        #expect(schema.field(withId: "batchNumber")?.isRequired == false)
        #expect(schema.field(withId: "notes")?.isRequired == false)
    }

    // MARK: - Condition Schema

    @Test
    func conditionSchema_hasCorrectId() {
        let schema = BuiltInSchemas.schema(for: .condition)
        #expect(schema.id == "condition")
        #expect(schema.displayName == "Medical Condition")
    }

    @Test
    func conditionSchema_hasRequiredFields() {
        let schema = BuiltInSchemas.schema(for: .condition)
        #expect(schema.field(withId: "conditionName")?.isRequired == true)
    }

    // MARK: - Medication Schema

    @Test
    func medicationSchema_hasCorrectId() {
        let schema = BuiltInSchemas.schema(for: .medication)
        #expect(schema.id == "medication")
    }

    @Test
    func medicationSchema_hasRequiredFields() {
        let schema = BuiltInSchemas.schema(for: .medication)
        #expect(schema.field(withId: "medicationName")?.isRequired == true)
    }

    @Test
    func medicationSchema_hasOptionalFields() {
        let schema = BuiltInSchemas.schema(for: .medication)
        #expect(schema.field(withId: "dosage")?.isRequired == false)
        #expect(schema.field(withId: "frequency")?.isRequired == false)
    }

    // MARK: - Allergy Schema

    @Test
    func allergySchema_hasCorrectId() {
        let schema = BuiltInSchemas.schema(for: .allergy)
        #expect(schema.id == "allergy")
    }

    @Test
    func allergySchema_hasRequiredFields() {
        let schema = BuiltInSchemas.schema(for: .allergy)
        #expect(schema.field(withId: "allergen")?.isRequired == true)
    }

    // MARK: - Note Schema

    @Test
    func noteSchema_hasCorrectId() {
        let schema = BuiltInSchemas.schema(for: .note)
        #expect(schema.id == "note")
    }

    @Test
    func noteSchema_hasRequiredFields() {
        let schema = BuiltInSchemas.schema(for: .note)
        #expect(schema.field(withId: "title")?.isRequired == true)
    }

    @Test
    func noteSchema_hasOptionalContent() {
        let schema = BuiltInSchemas.schema(for: .note)
        #expect(schema.field(withId: "content")?.isRequired == false)
    }

    // MARK: - All Schemas

    @Test
    func allSchemas_haveIcons() {
        for type in BuiltInSchemaType.allCases {
            let schema = BuiltInSchemas.schema(for: type)
            #expect(!schema.iconSystemName.isEmpty)
        }
    }

    @Test
    func allSchemas_haveUniqueIds() {
        let schemas = BuiltInSchemaType.allCases.map { BuiltInSchemas.schema(for: $0) }
        let ids = Set(schemas.map(\.id))
        #expect(ids.count == BuiltInSchemaType.allCases.count)
    }

    @Test
    func allSchemas_areMarkedBuiltIn() {
        for type in BuiltInSchemaType.allCases {
            let schema = BuiltInSchemas.schema(for: type)
            #expect(schema.isBuiltIn)
        }
    }

    // MARK: - Validation

    @Test
    func vaccineSchema_validatesRequiredFields() throws {
        let schema = BuiltInSchemas.schema(for: .vaccine)
        var content = RecordContent()

        // Should fail without required fields
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Add required fields
        content.setString("vaccineName", "COVID-19")
        content.setDate("dateAdministered", Date())

        // Should pass with required fields
        try schema.validate(content: content)
    }

    @Test
    func noteSchema_validatesRequiredTitle() throws {
        let schema = BuiltInSchemas.schema(for: .note)
        var content = RecordContent()

        // Should fail without title
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Add title
        content.setString("title", "My Note")

        // Should pass
        try schema.validate(content: content)
    }
}
