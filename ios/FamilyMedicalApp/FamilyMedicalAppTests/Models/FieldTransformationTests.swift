import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for FieldTransformation enum
struct FieldTransformationTests {
    // MARK: - Remove Transformation

    @Test("Remove transformation stores field ID correctly")
    func removeStoresFieldId() {
        let transformation = FieldTransformation.remove(fieldId: "testField")

        if case let .remove(fieldId) = transformation {
            #expect(fieldId == "testField")
        } else {
            Issue.record("Expected remove transformation")
        }
    }

    @Test("Remove transformation validates non-empty field ID")
    func removeValidatesNonEmptyFieldId() throws {
        let transformation = FieldTransformation.remove(fieldId: "validField")
        try transformation.validate()
    }

    @Test("Remove transformation throws for empty field ID")
    func removeThrowsForEmptyFieldId() {
        let transformation = FieldTransformation.remove(fieldId: "")

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    // MARK: - Type Convert Transformation

    @Test("TypeConvert transformation stores field ID and type correctly")
    func typeConvertStoresFieldIdAndType() {
        let transformation = FieldTransformation.typeConvert(fieldId: "numberField", toType: .int)

        if case let .typeConvert(fieldId, toType) = transformation {
            #expect(fieldId == "numberField")
            #expect(toType == .int)
        } else {
            Issue.record("Expected typeConvert transformation")
        }
    }

    @Test("TypeConvert validates supported types", arguments: [FieldType.string, FieldType.int, FieldType.double])
    func typeConvertValidatesSupportedTypes(targetType: FieldType) throws {
        let transformation = FieldTransformation.typeConvert(fieldId: "field", toType: targetType)
        try transformation.validate()
    }

    @Test("TypeConvert throws for unsupported types", arguments: [
        FieldType.bool, FieldType.date, FieldType.attachmentIds, FieldType.stringArray
    ])
    func typeConvertThrowsForUnsupportedTypes(targetType: FieldType) {
        let transformation = FieldTransformation.typeConvert(fieldId: "field", toType: targetType)

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    @Test("TypeConvert throws for empty field ID")
    func typeConvertThrowsForEmptyFieldId() {
        let transformation = FieldTransformation.typeConvert(fieldId: "", toType: .string)

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    // MARK: - Merge Transformation

    @Test("Merge transformation stores source and target correctly")
    func mergeStoresSourceAndTarget() {
        let transformation = FieldTransformation.merge(fieldId: "source", into: "target")

        if case let .merge(fieldId, into) = transformation {
            #expect(fieldId == "source")
            #expect(into == "target")
        } else {
            Issue.record("Expected merge transformation")
        }
    }

    @Test("Merge validates with valid source and target")
    func mergeValidatesWithValidFields() throws {
        let transformation = FieldTransformation.merge(fieldId: "firstName", into: "fullName")
        try transformation.validate()
    }

    @Test("Merge throws for empty source field ID")
    func mergeThrowsForEmptySourceFieldId() {
        let transformation = FieldTransformation.merge(fieldId: "", into: "target")

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    @Test("Merge throws for empty target field ID")
    func mergeThrowsForEmptyTargetFieldId() {
        let transformation = FieldTransformation.merge(fieldId: "source", into: "")

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    @Test("Merge throws when source equals target")
    func mergeThrowsWhenSourceEqualsTarget() {
        let transformation = FieldTransformation.merge(fieldId: "same", into: "same")

        #expect(throws: ModelError.self) {
            try transformation.validate()
        }
    }

    // MARK: - Affected Field IDs

    @Test("Remove returns correct affected field IDs")
    func removeAffectedFieldIds() {
        let transformation = FieldTransformation.remove(fieldId: "field1")
        #expect(transformation.affectedFieldIds == ["field1"])
    }

    @Test("TypeConvert returns correct affected field IDs")
    func typeConvertAffectedFieldIds() {
        let transformation = FieldTransformation.typeConvert(fieldId: "field1", toType: .int)
        #expect(transformation.affectedFieldIds == ["field1"])
    }

    @Test("Merge returns correct affected field IDs")
    func mergeAffectedFieldIds() {
        let transformation = FieldTransformation.merge(fieldId: "source", into: "target")
        let affectedIds = transformation.affectedFieldIds
        #expect(affectedIds.contains("source"))
        #expect(affectedIds.contains("target"))
        #expect(affectedIds.count == 2)
    }

    // MARK: - Type Checking

    @Test("isTypeConversion returns true for typeConvert")
    func isTypeConversionTrue() {
        let transformation = FieldTransformation.typeConvert(fieldId: "field", toType: .int)
        #expect(transformation.isTypeConversion)
    }

    @Test("isTypeConversion returns false for other transformations")
    func isTypeConversionFalse() {
        let remove = FieldTransformation.remove(fieldId: "field")
        let merge = FieldTransformation.merge(fieldId: "a", into: "b")

        #expect(!remove.isTypeConversion)
        #expect(!merge.isTypeConversion)
    }

    @Test("isMerge returns true for merge")
    func isMergeTrue() {
        let transformation = FieldTransformation.merge(fieldId: "a", into: "b")
        #expect(transformation.isMerge)
    }

    @Test("isMerge returns false for other transformations")
    func isMergeFalse() {
        let remove = FieldTransformation.remove(fieldId: "field")
        let typeConvert = FieldTransformation.typeConvert(fieldId: "field", toType: .int)

        #expect(!remove.isMerge)
        #expect(!typeConvert.isMerge)
    }

    // MARK: - Codable

    @Test("Remove transformation encodes and decodes correctly")
    func removeCodable() throws {
        let original = FieldTransformation.remove(fieldId: "testField")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FieldTransformation.self, from: data)

        #expect(decoded == original)
    }

    @Test("TypeConvert transformation encodes and decodes correctly")
    func typeConvertCodable() throws {
        let original = FieldTransformation.typeConvert(fieldId: "numberField", toType: .double)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FieldTransformation.self, from: data)

        #expect(decoded == original)
    }

    @Test("Merge transformation encodes and decodes correctly")
    func mergeCodable() throws {
        let original = FieldTransformation.merge(fieldId: "firstName", into: "fullName")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FieldTransformation.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Equality

    @Test("Transformations are equal when identical")
    func equalityWhenIdentical() {
        let first = FieldTransformation.remove(fieldId: "field")
        let second = FieldTransformation.remove(fieldId: "field")
        #expect(first == second)
    }

    @Test("Transformations are not equal when different")
    func inequalityWhenDifferent() {
        let first = FieldTransformation.remove(fieldId: "field1")
        let second = FieldTransformation.remove(fieldId: "field2")
        #expect(first != second)

        let third = FieldTransformation.typeConvert(fieldId: "field", toType: .int)
        #expect(first != third)
    }
}
