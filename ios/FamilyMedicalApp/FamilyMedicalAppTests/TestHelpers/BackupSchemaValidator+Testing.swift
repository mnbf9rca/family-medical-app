import Foundation
@testable import FamilyMedicalApp

extension BackupSchemaValidator {
    /// Create a validator configured for tests
    ///
    /// Uses `.main` bundle since hosted tests run inside the host app, which has the schema.
    /// This matches production behavior where the validator loads from `.main`.
    static func forTesting(
        maxNestingDepth: Int = 20,
        maxArraySize: Int = 100_000
    ) -> BackupSchemaValidator {
        BackupSchemaValidator(
            maxNestingDepth: maxNestingDepth,
            maxArraySize: maxArraySize,
            bundle: .main
        )
    }
}
