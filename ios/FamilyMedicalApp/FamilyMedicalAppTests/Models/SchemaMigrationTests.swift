import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for SchemaMigration model
struct SchemaMigrationTests {
    // MARK: - Valid Initialization

    @Test("Creates migration with valid parameters")
    func validInitialization() throws {
        let migration = try SchemaMigration(
            schemaId: "custom-lab-results",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "obsoleteField")]
        )

        #expect(migration.schemaId == "custom-lab-results")
        #expect(migration.fromVersion == 1)
        #expect(migration.toVersion == 2)
        #expect(migration.transformations.count == 1)
    }

    @Test("Creates migration with multiple transformations")
    func multipleTransformations() throws {
        let transformations: [FieldTransformation] = [
            .remove(fieldId: "field1"),
            .typeConvert(fieldId: "field2", toType: .int),
            .merge(fieldId: "firstName", into: "fullName")
        ]

        let migration = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: transformations
        )

        #expect(migration.transformations.count == 3)
    }

    @Test("Creates migration with version 0 to 1")
    func versionZeroToOne() throws {
        let migration = try SchemaMigration(
            schemaId: "new-schema",
            fromVersion: 0,
            toVersion: 1,
            transformations: [.remove(fieldId: "test")]
        )

        #expect(migration.fromVersion == 0)
        #expect(migration.toVersion == 1)
    }

    @Test("Creates migration with custom ID and date")
    func customIdAndDate() throws {
        let customId = UUID()
        let customDate = Date(timeIntervalSince1970: 1_000_000)

        let migration = try SchemaMigration(
            id: customId,
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")],
            createdAt: customDate
        )

        #expect(migration.id == customId)
        #expect(migration.createdAt == customDate)
    }

    // MARK: - Validation Errors

    @Test("Throws for empty schema ID")
    func emptySchemaIdThrows() {
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "",
                fromVersion: 1,
                toVersion: 2,
                transformations: [.remove(fieldId: "field")]
            )
        }
    }

    @Test("Throws for negative from version")
    func negativeFromVersionThrows() {
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: -1,
                toVersion: 1,
                transformations: [.remove(fieldId: "field")]
            )
        }
    }

    @Test("Throws when to version equals from version")
    func equalVersionsThrows() {
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: 2,
                toVersion: 2,
                transformations: [.remove(fieldId: "field")]
            )
        }
    }

    @Test("Throws when to version is less than from version")
    func toVersionLessThanFromThrows() {
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: 3,
                toVersion: 2,
                transformations: [.remove(fieldId: "field")]
            )
        }
    }

    @Test("Throws for empty transformations")
    func emptyTransformationsThrows() {
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: 1,
                toVersion: 2,
                transformations: []
            )
        }
    }

    @Test("Throws when transformation is invalid")
    func invalidTransformationThrows() {
        // Empty field ID in remove transformation
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: 1,
                toVersion: 2,
                transformations: [.remove(fieldId: "")]
            )
        }
    }

    @Test("Throws when duplicate field ID appears in multiple transformations")
    func duplicateFieldIdThrows() {
        // Same field appears in both remove and typeConvert
        #expect(throws: ModelError.self) {
            try SchemaMigration(
                schemaId: "test",
                fromVersion: 1,
                toVersion: 2,
                transformations: [
                    .remove(fieldId: "duplicateField"),
                    .typeConvert(fieldId: "duplicateField", toType: .string)
                ]
            )
        }
    }

    // MARK: - Computed Properties

    @Test("hasTypeConversions returns true when present")
    func hasTypeConversionsTrue() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [
                .remove(fieldId: "field1"),
                .typeConvert(fieldId: "field2", toType: .int)
            ]
        )

        #expect(migration.hasTypeConversions)
    }

    @Test("hasTypeConversions returns false when absent")
    func hasTypeConversionsFalse() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field1")]
        )

        #expect(!migration.hasTypeConversions)
    }

    @Test("hasMerges returns true when present")
    func hasMergesTrue() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.merge(fieldId: "source", into: "target")]
        )

        #expect(migration.hasMerges)
    }

    @Test("hasMerges returns false when absent")
    func hasMergesFalse() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.typeConvert(fieldId: "field", toType: .string)]
        )

        #expect(!migration.hasMerges)
    }

    @Test("affectedFieldIds returns all fields")
    func affectedFieldIdsComplete() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [
                .remove(fieldId: "removed"),
                .typeConvert(fieldId: "converted", toType: .int),
                .merge(fieldId: "source", into: "merged")
            ]
        )

        let affected = migration.affectedFieldIds
        #expect(affected.contains("removed"))
        #expect(affected.contains("converted"))
        #expect(affected.contains("source"))
        #expect(affected.contains("merged"))
        #expect(affected.count == 4)
    }

    // MARK: - Codable

    @Test("Encodes and decodes correctly")
    func codableRoundTrip() throws {
        let original = try SchemaMigration(
            schemaId: "test-schema",
            fromVersion: 1,
            toVersion: 2,
            transformations: [
                .remove(fieldId: "field1"),
                .typeConvert(fieldId: "field2", toType: .double),
                .merge(fieldId: "source", into: "target")
            ]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SchemaMigration.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.schemaId == original.schemaId)
        #expect(decoded.fromVersion == original.fromVersion)
        #expect(decoded.toVersion == original.toVersion)
        #expect(decoded.transformations == original.transformations)
    }

    // MARK: - Equality

    @Test("Migrations are equal when identical")
    func equalityWhenIdentical() throws {
        let migrationId = UUID()
        let date = Date()

        let first = try SchemaMigration(
            id: migrationId,
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")],
            createdAt: date
        )

        let second = try SchemaMigration(
            id: migrationId,
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")],
            createdAt: date
        )

        #expect(first == second)
    }

    @Test("Migrations are not equal when different")
    func inequalityWhenDifferent() throws {
        let first = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field1")]
        )

        let second = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field2")]
        )

        #expect(first != second)
    }

    // MARK: - Hashable

    @Test("Migrations can be used in sets")
    func hashableInSet() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")]
        )

        var set = Set<SchemaMigration>()
        set.insert(migration)

        #expect(set.contains(migration))
    }
}
