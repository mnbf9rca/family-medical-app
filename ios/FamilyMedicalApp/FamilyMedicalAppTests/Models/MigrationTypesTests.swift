import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for MigrationTypes (MigrationOptions, MergeStrategy, MigrationPreview, MigrationProgress, MigrationResult)
struct MigrationTypesTests {
    // MARK: - MigrationOptions Tests

    @Test("MigrationOptions default uses concatenate strategy")
    func migrationOptionsDefault() {
        let options = MigrationOptions.default

        if case let .concatenate(separator) = options.mergeStrategy {
            #expect(separator == " ")
        } else {
            Issue.record("Expected concatenate strategy")
        }
    }

    @Test("MigrationOptions is Codable")
    func migrationOptionsCodable() throws {
        let options = MigrationOptions(mergeStrategy: .preferTarget)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(options)
        let decoded = try decoder.decode(MigrationOptions.self, from: data)

        #expect(decoded == options)
    }

    @Test("MigrationOptions equality")
    func migrationOptionsEquality() {
        let first = MigrationOptions(mergeStrategy: .preferTarget)
        let second = MigrationOptions(mergeStrategy: .preferTarget)
        let third = MigrationOptions(mergeStrategy: .preferSource)

        #expect(first == second)
        #expect(first != third)
    }

    // MARK: - MergeStrategy Tests

    @Test("MergeStrategy concatenate with custom separator")
    func mergeStrategyConcatenate() {
        let strategy = MergeStrategy.concatenate(separator: ", ")

        if case let .concatenate(separator) = strategy {
            #expect(separator == ", ")
        } else {
            Issue.record("Expected concatenate strategy")
        }
    }

    @Test("MergeStrategy is Codable")
    func mergeStrategyCodable() throws {
        let strategies: [MergeStrategy] = [
            .concatenate(separator: "-"),
            .preferSource,
            .preferTarget
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for strategy in strategies {
            let data = try encoder.encode(strategy)
            let decoded = try decoder.decode(MergeStrategy.self, from: data)
            #expect(decoded == strategy)
        }
    }

    @Test("MergeStrategy equality")
    func mergeStrategyEquality() {
        let first = MergeStrategy.concatenate(separator: " ")
        let second = MergeStrategy.concatenate(separator: " ")
        let third = MergeStrategy.concatenate(separator: ", ")
        let preferSourceStrategy = MergeStrategy.preferSource
        let preferTargetStrategy = MergeStrategy.preferTarget

        #expect(first == second)
        #expect(first != third)
        #expect(preferSourceStrategy != preferTargetStrategy)
    }

    @Test("MergeStrategy is Hashable")
    func mergeStrategyHashable() {
        var set = Set<MergeStrategy>()
        set.insert(.preferSource)
        set.insert(.preferSource)
        set.insert(.preferTarget)

        #expect(set.count == 2)
    }

    @Test("MergeStrategy strategyType returns correct type")
    func mergeStrategyTypeProperty() {
        #expect(MergeStrategy.concatenate(separator: " ").strategyType == .concatenate)
        #expect(MergeStrategy.concatenate(separator: ", ").strategyType == .concatenate)
        #expect(MergeStrategy.preferSource.strategyType == .preferSource)
        #expect(MergeStrategy.preferTarget.strategyType == .preferTarget)
    }

    // MARK: - MergeStrategyType Tests

    @Test("MergeStrategyType defaultStrategy returns correct strategy")
    func mergeStrategyTypeDefaultStrategy() {
        if case let .concatenate(separator) = MergeStrategyType.concatenate.defaultStrategy {
            #expect(separator == " ")
        } else {
            Issue.record("Expected concatenate strategy")
        }

        #expect(MergeStrategyType.preferSource.defaultStrategy == .preferSource)
        #expect(MergeStrategyType.preferTarget.defaultStrategy == .preferTarget)
    }

    @Test("MergeStrategyType is CaseIterable")
    func mergeStrategyTypeCaseIterable() {
        #expect(MergeStrategyType.allCases.count == 3)
        #expect(MergeStrategyType.allCases.contains(.concatenate))
        #expect(MergeStrategyType.allCases.contains(.preferSource))
        #expect(MergeStrategyType.allCases.contains(.preferTarget))
    }

    @Test("MergeStrategyType is Hashable")
    func mergeStrategyTypeHashable() {
        var set = Set<MergeStrategyType>()
        set.insert(.concatenate)
        set.insert(.concatenate)
        set.insert(.preferSource)

        #expect(set.count == 2)
    }

    // MARK: - MigrationPreview Tests

    @Test("MigrationPreview empty static property")
    func migrationPreviewEmpty() {
        let empty = MigrationPreview.empty

        #expect(empty.recordCount == 0)
        #expect(empty.sampleRecordId == nil)
        #expect(empty.warnings.isEmpty)
    }

    @Test("MigrationPreview with values")
    func migrationPreviewWithValues() {
        let sampleId = UUID()
        let preview = MigrationPreview(
            recordCount: 10,
            sampleRecordId: sampleId,
            warnings: ["Warning 1", "Warning 2"]
        )

        #expect(preview.recordCount == 10)
        #expect(preview.sampleRecordId == sampleId)
        #expect(preview.warnings.count == 2)
    }

    @Test("MigrationPreview equality")
    func migrationPreviewEquality() {
        let sampleId = UUID()
        let first = MigrationPreview(recordCount: 5, sampleRecordId: sampleId, warnings: ["warn"])
        let second = MigrationPreview(recordCount: 5, sampleRecordId: sampleId, warnings: ["warn"])
        let third = MigrationPreview(recordCount: 10, sampleRecordId: sampleId, warnings: ["warn"])

        #expect(first == second)
        #expect(first != third)
    }

    // MARK: - MigrationProgress Tests

    @Test("MigrationProgress progress calculation")
    func migrationProgressCalculation() {
        let progress = MigrationProgress(totalRecords: 10, processedRecords: 5, currentRecordId: nil)

        #expect(progress.progress == 0.5)
        #expect(progress.percentComplete == 50)
    }

    @Test("MigrationProgress zero total returns zero progress")
    func migrationProgressZeroTotal() {
        let progress = MigrationProgress(totalRecords: 0, processedRecords: 0, currentRecordId: nil)

        #expect(progress.progress == 0)
        #expect(progress.percentComplete == 0)
    }

    @Test("MigrationProgress complete")
    func migrationProgressComplete() {
        let progress = MigrationProgress(totalRecords: 20, processedRecords: 20, currentRecordId: nil)

        #expect(progress.progress == 1.0)
        #expect(progress.percentComplete == 100)
    }

    @Test("MigrationProgress equality")
    func migrationProgressEquality() {
        let recordId = UUID()
        let first = MigrationProgress(totalRecords: 10, processedRecords: 5, currentRecordId: recordId)
        let second = MigrationProgress(totalRecords: 10, processedRecords: 5, currentRecordId: recordId)
        let third = MigrationProgress(totalRecords: 10, processedRecords: 6, currentRecordId: recordId)

        #expect(first == second)
        #expect(first != third)
    }

    // MARK: - MigrationResult Tests

    @Test("MigrationResult isSuccess when no failures")
    func migrationResultIsSuccessTrue() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")]
        )

        let result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 10,
            recordsFailed: 0,
            errors: [],
            startTime: Date(),
            endTime: Date()
        )

        #expect(result.isSuccess)
    }

    @Test("MigrationResult isSuccess false when failures exist")
    func migrationResultIsSuccessFalse() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")]
        )

        let result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 8,
            recordsFailed: 2,
            errors: [
                MigrationRecordError(recordId: UUID(), fieldId: nil, reason: "Error")
            ],
            startTime: Date(),
            endTime: Date()
        )

        #expect(!result.isSuccess)
    }

    @Test("MigrationResult duration calculation")
    func migrationResultDuration() throws {
        let migration = try SchemaMigration(
            schemaId: "test",
            fromVersion: 1,
            toVersion: 2,
            transformations: [.remove(fieldId: "field")]
        )

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(5.5)

        let result = MigrationResult(
            migration: migration,
            recordsProcessed: 10,
            recordsSucceeded: 10,
            recordsFailed: 0,
            errors: [],
            startTime: startTime,
            endTime: endTime
        )

        #expect(result.duration == 5.5)
    }

    // MARK: - MigrationRecordError Tests

    @Test("MigrationRecordError stores values correctly")
    func migrationRecordErrorValues() {
        let recordId = UUID()
        let error = MigrationRecordError(
            recordId: recordId,
            fieldId: "numberField",
            reason: "Could not convert to int"
        )

        #expect(error.recordId == recordId)
        #expect(error.fieldId == "numberField")
        #expect(error.reason == "Could not convert to int")
    }

    @Test("MigrationRecordError without fieldId")
    func migrationRecordErrorNoFieldId() {
        let recordId = UUID()
        let error = MigrationRecordError(
            recordId: recordId,
            fieldId: nil,
            reason: "General error"
        )

        #expect(error.fieldId == nil)
    }

    @Test("MigrationRecordError equality")
    func migrationRecordErrorEquality() {
        let recordId = UUID()
        let first = MigrationRecordError(recordId: recordId, fieldId: "field", reason: "error")
        let second = MigrationRecordError(recordId: recordId, fieldId: "field", reason: "error")
        let third = MigrationRecordError(recordId: recordId, fieldId: "other", reason: "error")

        #expect(first == second)
        #expect(first != third)
    }

    @Test("MigrationRecordError is Hashable")
    func migrationRecordErrorHashable() {
        let recordId = UUID()
        let error = MigrationRecordError(recordId: recordId, fieldId: "field", reason: "error")

        var set = Set<MigrationRecordError>()
        set.insert(error)
        set.insert(error)

        #expect(set.count == 1)
    }
}
