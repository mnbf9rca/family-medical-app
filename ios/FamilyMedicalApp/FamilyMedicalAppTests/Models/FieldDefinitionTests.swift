import Foundation
import Testing
@testable import FamilyMedicalApp

struct FieldDefinitionTests {
    // MARK: - FieldType

    @Test
    func fieldType_displayName_allTypes() {
        #expect(FieldType.string.displayName == "Text")
        #expect(FieldType.int.displayName == "Number (Integer)")
        #expect(FieldType.double.displayName == "Number (Decimal)")
        #expect(FieldType.bool.displayName == "Yes/No")
        #expect(FieldType.date.displayName == "Date")
        #expect(FieldType.attachmentIds.displayName == "Attachments")
        #expect(FieldType.stringArray.displayName == "List of Text")
    }

    @Test
    func fieldType_matches_correctType_returnsTrue() {
        #expect(FieldType.string.matches(.string("test")))
        #expect(FieldType.int.matches(.int(42)))
        #expect(FieldType.double.matches(.double(3.14)))
        #expect(FieldType.bool.matches(.bool(true)))
        #expect(FieldType.date.matches(.date(Date())))
        #expect(FieldType.attachmentIds.matches(.attachmentIds([UUID()])))
        #expect(FieldType.stringArray.matches(.stringArray(["test"])))
    }

    @Test
    func fieldType_matches_wrongType_returnsFalse() {
        #expect(!FieldType.string.matches(.int(42)))
        #expect(!FieldType.int.matches(.string("42")))
        #expect(!FieldType.double.matches(.int(42)))
        #expect(!FieldType.bool.matches(.string("true")))
        #expect(!FieldType.date.matches(.string("2025-01-01")))
        #expect(!FieldType.attachmentIds.matches(.stringArray(["id"])))
        #expect(!FieldType.stringArray.matches(.attachmentIds([UUID()])))
    }

    // MARK: - ValidationRule Codable

    @Test
    func validationRule_codable_minLength() throws {
        let original = ValidationRule.minLength(5)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_maxLength() throws {
        let original = ValidationRule.maxLength(100)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_minValue() throws {
        let original = ValidationRule.minValue(0.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_maxValue() throws {
        let original = ValidationRule.maxValue(100.5)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_minDate() throws {
        let date = Date(timeIntervalSince1970: 0)
        let original = ValidationRule.minDate(date)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_maxDate() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let original = ValidationRule.maxDate(date)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func validationRule_codable_pattern() throws {
        let original = ValidationRule.pattern("^[a-z]+$")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ValidationRule.self, from: encoded)
        #expect(decoded == original)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = FieldDefinition.builtIn(
            id: BuiltInFieldIds.Vaccine.name,
            displayName: "Vaccine Name",
            fieldType: .string,
            isRequired: true,
            displayOrder: 1,
            placeholder: "e.g., COVID-19",
            helpText: "Name of the vaccine",
            validationRules: [.minLength(1), .maxLength(200)]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldDefinition.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.validationRules == original.validationRules)
    }

    // MARK: - FieldDefinition.builtIn

    @Test
    func builtIn_setsSystemProvenance() {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Test Field",
            fieldType: .string
        )

        #expect(field.createdBy == .zero)
        #expect(field.createdAt == .distantPast)
        #expect(field.updatedBy == .zero)
        #expect(field.updatedAt == .distantPast)
        #expect(field.visibility == .active)
    }

    // MARK: - FieldDefinition.userCreated

    @Test
    func userCreated_setsUserProvenance() {
        let deviceId = UUID()
        let beforeCreation = Date()

        let field = FieldDefinition.userCreated(
            displayName: "Custom Field",
            fieldType: .string,
            deviceId: deviceId
        )

        let afterCreation = Date()

        #expect(field.createdBy == deviceId)
        #expect(field.updatedBy == deviceId)
        #expect(field.createdAt >= beforeCreation)
        #expect(field.createdAt <= afterCreation)
        #expect(field.updatedAt >= beforeCreation)
        #expect(field.updatedAt <= afterCreation)
        #expect(field.visibility == .active)
        // User-created fields get auto-generated UUID
        #expect(field.id != .zero)
    }

    // MARK: - Visibility

    @Test
    func visibility_codable() throws {
        for visibility in FieldVisibility.allCases {
            let encoded = try JSONEncoder().encode(visibility)
            let decoded = try JSONDecoder().decode(FieldVisibility.self, from: encoded)
            #expect(decoded == visibility)
        }
    }
}
