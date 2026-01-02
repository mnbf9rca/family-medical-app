import Foundation
import Testing
@testable import FamilyMedicalApp

struct RepositoryErrorsTests {
    // MARK: - Core Data Errors

    @Test
    func entityNotFound_hasCorrectDescription() {
        let error = RepositoryError.entityNotFound("Test entity details")

        #expect(error.localizedDescription == "Entity not found: Test entity details")
    }

    @Test
    func saveFailed_hasCorrectDescription() {
        let error = RepositoryError.saveFailed("Test save error")

        #expect(error.localizedDescription == "Failed to save to database: Test save error")
    }

    @Test
    func fetchFailed_hasCorrectDescription() {
        let error = RepositoryError.fetchFailed("Test fetch error")

        #expect(error.localizedDescription == "Failed to fetch from database: Test fetch error")
    }

    @Test
    func deleteFailed_hasCorrectDescription() {
        let error = RepositoryError.deleteFailed("Test delete error")

        #expect(error.localizedDescription == "Failed to delete from database: Test delete error")
    }

    // MARK: - Encryption Errors

    @Test
    func encryptionFailed_hasCorrectDescription() {
        let error = RepositoryError.encryptionFailed("Test encryption error")

        #expect(error.localizedDescription == "Encryption failed: Test encryption error")
    }

    @Test
    func decryptionFailed_hasCorrectDescription() {
        let error = RepositoryError.decryptionFailed("Test decryption error")

        #expect(error.localizedDescription == "Decryption failed: Test decryption error")
    }

    @Test
    func keyNotAvailable_hasCorrectDescription() {
        let error = RepositoryError.keyNotAvailable("Test key error")

        #expect(error.localizedDescription == "Encryption key not available: Test key error")
    }

    // MARK: - Validation Errors

    @Test
    func validationFailed_hasCorrectDescription() {
        let error = RepositoryError.validationFailed("Test validation error")

        #expect(error.localizedDescription == "Validation failed: Test validation error")
    }

    @Test
    func duplicateEntity_hasCorrectDescription() {
        let testID = UUID()
        let error = RepositoryError.duplicateEntity(testID)

        #expect(error.localizedDescription == "Entity with ID \(testID) already exists")
    }

    // MARK: - Serialization Errors

    @Test
    func serializationFailed_hasCorrectDescription() {
        let error = RepositoryError.serializationFailed("Test serialization error")

        #expect(error.localizedDescription == "Serialization failed: Test serialization error")
    }

    @Test
    func deserializationFailed_hasCorrectDescription() {
        let error = RepositoryError.deserializationFailed("Test deserialization error")

        #expect(error.localizedDescription == "Deserialization failed: Test deserialization error")
    }

    // MARK: - Schema Validation Errors

    @Test
    func schemaIdConflictsWithBuiltIn_hasCorrectDescription() {
        let error = RepositoryError.schemaIdConflictsWithBuiltIn("vaccination")

        #expect(error.localizedDescription == "Schema ID 'vaccination' conflicts with a built-in schema")
    }

    @Test
    func customSchemaNotFound_hasCorrectDescription() {
        let error = RepositoryError.customSchemaNotFound("my-custom-schema")

        #expect(error.localizedDescription == "Custom schema 'my-custom-schema' not found")
    }

    @Test
    func fieldTypeChangeNotAllowed_hasCorrectDescription() {
        let error = RepositoryError.fieldTypeChangeNotAllowed(fieldId: "age", from: .string, to: .int)

        #expect(error.localizedDescription == "Cannot change field type for 'age' from string to int")
    }

    @Test
    func schemaVersionNotIncremented_hasCorrectDescription() {
        let error = RepositoryError.schemaVersionNotIncremented(current: 2, expected: 3)

        #expect(error.localizedDescription == "Schema version must be incremented (current: 2, expected: 3)")
    }

    // MARK: - Migration Errors

    @Test
    func migrationFailed_hasCorrectDescription() {
        let error = RepositoryError.migrationFailed("Test migration error")

        #expect(error.localizedDescription == "Migration failed: Test migration error")
    }

    @Test
    func migrationRollbackFailed_hasCorrectDescription() {
        let error = RepositoryError.migrationRollbackFailed("Test rollback error")

        #expect(error.localizedDescription == "Migration rollback failed: Test rollback error")
    }

    @Test
    func checkpointNotFound_hasCorrectDescription() {
        let migrationId = UUID()
        let error = RepositoryError.checkpointNotFound(migrationId)

        #expect(error.localizedDescription == "Migration checkpoint not found: \(migrationId)")
    }

    @Test
    func checkpointAlreadyExists_hasCorrectDescription() {
        let migrationId = UUID()
        let error = RepositoryError.checkpointAlreadyExists(migrationId)

        #expect(error.localizedDescription == "Checkpoint already exists for migration: \(migrationId)")
    }

    // MARK: - Equality Tests

    @Test
    func errors_areEqual_whenSame() {
        let errorOne = RepositoryError.migrationFailed("error")
        let errorTwo = RepositoryError.migrationFailed("error")

        #expect(errorOne == errorTwo)
    }

    @Test
    func errors_areNotEqual_whenDifferent() {
        let errorOne = RepositoryError.migrationFailed("error1")
        let errorTwo = RepositoryError.migrationFailed("error2")

        #expect(errorOne != errorTwo)
    }
}
