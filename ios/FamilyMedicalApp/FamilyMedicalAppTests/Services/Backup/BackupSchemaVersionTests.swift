import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("Backup Schema Version Tests")
struct BackupSchemaVersionTests {
    @Test("Validator reports schema version")
    func validatorReportsSchemaVersion() {
        let validator = BackupSchemaValidator.forTesting()
        #expect(validator.schemaVersion == "1.0")
    }

    @Test("Future version detection")
    func futureVersionDetected() {
        let validator = BackupSchemaValidator.forTesting()

        // JSON with formatVersion 2.0 (future)
        let futureJSON = Data("""
        {
            "formatName": "RecordWell Backup",
            "formatVersion": "2.0",
            "generator": "Test",
            "encrypted": false,
            "checksum": {"algorithm": "SHA-256", "value": "dGVzdA=="},
            "data": {
                "exportedAt": "2026-02-01T12:00:00Z",
                "appVersion": "1.0.0",
                "metadata": {"personCount": 0, "recordCount": 0, "attachmentCount": 0, "schemaCount": 0},
                "persons": [],
                "records": [],
                "attachments": [],
                "schemas": []
            }
        }
        """.utf8)

        // Should still validate against v1 schema (formatVersion is just a string pattern)
        // But the app can check formatVersion and warn about newer versions
        let result = validator.validate(jsonData: futureJSON)
        #expect(result.isValid) // Schema allows any X.Y format
    }
}
