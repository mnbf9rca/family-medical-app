import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for FieldDefinition UI metadata properties (isMultiline, capitalizationMode)
struct FieldDefinitionUIMetadataTests {
    // MARK: - UI Metadata - Defaults

    @Test
    func init_defaultUIMetadata_hasCorrectDefaults() {
        let definition = FieldDefinition(
            id: "test",
            displayName: "Test",
            fieldType: .string
        )

        #expect(definition.isMultiline == false)
        #expect(definition.capitalizationMode == .sentences)
    }

    // MARK: - UI Metadata - Custom Values

    @Test
    func init_customUIMetadata_preservesValues() {
        let definition = FieldDefinition(
            id: "notes",
            displayName: "Notes",
            fieldType: .string,
            isMultiline: true,
            capitalizationMode: .words
        )

        #expect(definition.isMultiline == true)
        #expect(definition.capitalizationMode == .words)
    }

    @Test
    func init_multilineWithSentences_preservesBoth() {
        let definition = FieldDefinition(
            id: "content",
            displayName: "Content",
            fieldType: .string,
            isMultiline: true,
            capitalizationMode: .sentences
        )

        #expect(definition.isMultiline)
        #expect(definition.capitalizationMode == .sentences)
    }

    @Test
    func init_singleLineWithNone_preservesBoth() {
        let definition = FieldDefinition(
            id: "code",
            displayName: "Code",
            fieldType: .string,
            isMultiline: false,
            capitalizationMode: .none
        )

        #expect(!definition.isMultiline)
        #expect(definition.capitalizationMode == .none)
    }

    // MARK: - TextCapitalizationMode - Encoding/Decoding

    @Test
    func textCapitalizationMode_encodesDecode_none() throws {
        let original = TextCapitalizationMode.none
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextCapitalizationMode.self, from: data)
        #expect(decoded == .none)
    }

    @Test
    func textCapitalizationMode_encodesDecode_words() throws {
        let original = TextCapitalizationMode.words
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextCapitalizationMode.self, from: data)
        #expect(decoded == .words)
    }

    @Test
    func textCapitalizationMode_encodesDecode_sentences() throws {
        let original = TextCapitalizationMode.sentences
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextCapitalizationMode.self, from: data)
        #expect(decoded == .sentences)
    }

    @Test
    func textCapitalizationMode_encodesDecode_allCharacters() throws {
        let original = TextCapitalizationMode.allCharacters
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextCapitalizationMode.self, from: data)
        #expect(decoded == .allCharacters)
    }

    // MARK: - FieldDefinition with UI Metadata - Encoding/Decoding

    @Test
    func fieldDefinition_encodeDecode_preservesUIMetadata() throws {
        let original = FieldDefinition(
            id: "notes",
            displayName: "Notes",
            fieldType: .string,
            isRequired: false,
            displayOrder: 1,
            placeholder: "Enter notes",
            helpText: "Additional information",
            validationRules: [.maxLength(1_000)],
            isMultiline: true,
            capitalizationMode: .words
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FieldDefinition.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.fieldType == original.fieldType)
        #expect(decoded.isMultiline == true)
        #expect(decoded.capitalizationMode == .words)
    }

    @Test
    func fieldDefinition_encodeDecode_defaultUIMetadata() throws {
        // Field with default UI metadata should decode correctly
        let original = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldDefinition.self, from: data)

        #expect(decoded.isMultiline == false)
        #expect(decoded.capitalizationMode == .sentences)
    }
}
