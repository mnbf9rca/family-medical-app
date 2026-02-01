import Foundation
@testable import FamilyMedicalApp

extension BackupSchemaValidator {
    /// Create a validator configured for tests, using the test bundle for schema loading
    static func forTesting(
        maxNestingDepth: Int = 20,
        maxArraySize: Int = 100_000
    ) -> BackupSchemaValidator {
        BackupSchemaValidator(
            maxNestingDepth: maxNestingDepth,
            maxArraySize: maxArraySize,
            bundle: TestBundle.bundle
        )
    }
}
