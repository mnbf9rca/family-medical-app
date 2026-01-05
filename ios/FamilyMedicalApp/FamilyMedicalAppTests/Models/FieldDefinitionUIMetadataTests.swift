import Foundation
import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for FieldDefinition UI metadata properties (isMultiline, capitalizationMode)
struct FieldDefinitionUIMetadataTests {
    // MARK: - UI Metadata - Defaults

    @Test
    func init_defaultUIMetadata_hasCorrectDefaults() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Test",
            fieldType: .string
        )

        #expect(definition.isMultiline == false)
        #expect(definition.capitalizationMode == .sentences)
    }

    // MARK: - UI Metadata - Custom Values

    @Test
    func init_customUIMetadata_preservesValues() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
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
        let definition = FieldDefinition.builtIn(
            id: UUID(),
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
        let definition = FieldDefinition.builtIn(
            id: UUID(),
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
        let fieldId = UUID()
        let original = FieldDefinition.builtIn(
            id: fieldId,
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
        let original = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldDefinition.self, from: data)

        #expect(decoded.isMultiline == false)
        #expect(decoded.capitalizationMode == .sentences)
    }

    // MARK: - TextCapitalizationMode - SwiftUI Conversion

    @Test
    func textCapitalizationMode_toSwiftUI_allCases() {
        // Test all cases to ensure complete coverage of the switch statement
        // We can't use == on TextInputAutocapitalization directly, so just verify
        // the properties return without crashing and are the expected type
        let noneResult: TextInputAutocapitalization = TextCapitalizationMode.none.toSwiftUI
        let wordsResult: TextInputAutocapitalization = TextCapitalizationMode.words.toSwiftUI
        let sentencesResult: TextInputAutocapitalization = TextCapitalizationMode.sentences.toSwiftUI
        let allCharsResult: TextInputAutocapitalization = TextCapitalizationMode.allCharacters.toSwiftUI

        // Verify type assignment succeeds (compile-time check)
        // and that we get different results for different inputs (runtime check using description)
        let descriptions = [
            String(describing: noneResult),
            String(describing: wordsResult),
            String(describing: sentencesResult),
            String(describing: allCharsResult)
        ]

        // Verify each case produces a different result (uniqueness check)
        let uniqueDescriptions = Set(descriptions)
        #expect(uniqueDescriptions.count == 4, "Each capitalization mode should produce a unique result")
    }
}
