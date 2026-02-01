import Foundation
import JSONSchema

/// Result of validating JSON against the backup schema
struct BackupValidationResult: Equatable, Sendable {
    /// Whether the JSON is valid according to the schema
    let isValid: Bool

    /// List of validation errors (empty if valid)
    let errors: [String]

    static let valid = BackupValidationResult(isValid: true, errors: [])

    static func invalid(_ errors: [String]) -> BackupValidationResult {
        BackupValidationResult(isValid: false, errors: errors)
    }
}

/// Protocol for backup schema validation
protocol BackupSchemaValidatorProtocol: Sendable {
    /// The version of the schema this validator uses
    var schemaVersion: String { get }

    /// Validate JSON data against the backup schema
    func validate(jsonData: Data) -> BackupValidationResult
}

/// Validates backup JSON against the schema before decoding
///
/// Provides defense-in-depth against malformed or malicious backup files:
/// - Validates structure against JSON Schema Draft 2020-12
/// - Enforces maximum nesting depth to prevent stack overflow
/// - Enforces maximum array sizes to prevent memory exhaustion
final class BackupSchemaValidator: BackupSchemaValidatorProtocol, @unchecked Sendable {
    // MARK: - Configuration

    /// Maximum allowed nesting depth in the JSON structure
    let maxNestingDepth: Int

    /// Maximum allowed size for any array in the JSON
    let maxArraySize: Int

    /// The version of the schema this validator uses
    var schemaVersion: String {
        "1.0" // Matches backup-v1.json
    }

    // MARK: - Private Properties

    private let schema: Schema?
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    /// Create a validator with optional DoS protection limits
    ///
    /// - Parameters:
    ///   - maxNestingDepth: Maximum nesting depth (default: 20)
    ///   - maxArraySize: Maximum array size (default: 100_000)
    ///   - logger: Optional logger for debug output
    init(
        maxNestingDepth: Int = 20,
        maxArraySize: Int = 100_000,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.maxNestingDepth = maxNestingDepth
        self.maxArraySize = maxArraySize
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)

        // Load schema from bundle
        self.schema = Self.loadSchema()
    }

    // MARK: - BackupSchemaValidatorProtocol

    func validate(jsonData: Data) -> BackupValidationResult {
        logger.debug("Validating backup JSON against schema")

        // Step 1: Try to parse JSON first to catch malformed input
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        } catch {
            logger.error("Failed to parse JSON: \(error.localizedDescription)")
            return .invalid(["Invalid JSON: \(error.localizedDescription)"])
        }

        // Step 2: Check DoS limits before schema validation
        let dosResult = checkDoSLimits(jsonObject)
        if !dosResult.isValid {
            logger.notice("DoS limit exceeded: \(dosResult.errors.joined(separator: ", "))")
            return dosResult
        }

        // Step 3: Validate against schema (if available)
        guard let schema else {
            logger.notice("Schema not available, skipping schema validation")
            return .valid
        }

        // Convert to JSONValue for schema validation
        let jsonValue: JSONValue
        do {
            jsonValue = try JSONDecoder().decode(JSONValue.self, from: jsonData)
        } catch {
            logger.error("Failed to decode JSON to JSONValue: \(error.localizedDescription)")
            return .invalid(["Failed to decode JSON: \(error.localizedDescription)"])
        }

        // Validate against schema
        let result = schema.validate(jsonValue, at: .init())

        if result.isValid {
            logger.debug("Backup JSON validated successfully")
            return .valid
        } else {
            let errors = Self.flattenErrors(result.errors ?? [])
            logger.notice("Schema validation failed: \(errors.joined(separator: ", "))")
            return .invalid(errors)
        }
    }

    // MARK: - Private Methods

    private static func loadSchema() -> Schema? {
        let logger = LoggingService.shared.logger(category: .storage)

        // Try loading from bundle first
        if let schemaURL = Bundle.main.url(forResource: "backup-v1", withExtension: "json", subdirectory: "Schemas"),
           let schemaData = try? Data(contentsOf: schemaURL),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.notice("Failed to parse bundled schema: \(error.localizedDescription)")
            }
        }

        // Try loading from Resources directory (flat structure)
        if let schemaURL = Bundle.main.url(forResource: "backup-v1", withExtension: "json"),
           let schemaData = try? Data(contentsOf: schemaURL),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.notice("Failed to parse schema from Resources: \(error.localizedDescription)")
            }
        }

        // During tests, try loading from project directory
        let projectSchemaPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Backup
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // FamilyMedicalApp
            .deletingLastPathComponent() // FamilyMedicalApp
            .deletingLastPathComponent() // ios
            .appendingPathComponent("docs")
            .appendingPathComponent("schemas")
            .appendingPathComponent("backup-v1.json")

        if let schemaData = try? Data(contentsOf: projectSchemaPath),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.notice("Failed to parse project schema: \(error.localizedDescription)")
            }
        }

        return nil
    }

    private func checkDoSLimits(_ jsonObject: Any) -> BackupValidationResult {
        var errors: [String] = []

        // Check nesting depth
        let depth = calculateDepth(jsonObject)
        if depth > maxNestingDepth {
            errors.append("JSON nesting depth (\(depth)) exceeds maximum allowed (\(maxNestingDepth))")
        }

        // Check array sizes
        let maxFoundArraySize = findMaxArraySize(jsonObject)
        if maxFoundArraySize > maxArraySize {
            errors.append("Array size (\(maxFoundArraySize)) exceeds maximum allowed (\(maxArraySize))")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }

    private func calculateDepth(_ value: Any, currentDepth: Int = 1) -> Int {
        switch value {
        case let dict as [String: Any]:
            let childDepths = dict.values.map { calculateDepth($0, currentDepth: currentDepth + 1) }
            return childDepths.max() ?? currentDepth
        case let array as [Any]:
            let childDepths = array.map { calculateDepth($0, currentDepth: currentDepth + 1) }
            return childDepths.max() ?? currentDepth
        default:
            return currentDepth
        }
    }

    private func findMaxArraySize(_ value: Any) -> Int {
        switch value {
        case let dict as [String: Any]:
            let childMaxes = dict.values.map { findMaxArraySize($0) }
            return childMaxes.max() ?? 0
        case let array as [Any]:
            let selfSize = array.count
            let childMaxes = array.map { findMaxArraySize($0) }
            return max(selfSize, childMaxes.max() ?? 0)
        default:
            return 0
        }
    }

    /// Flatten nested validation errors into simple string messages
    private static func flattenErrors(_ errors: [ValidationError]) -> [String] {
        var result: [String] = []

        for error in errors {
            let message = if error.message.isEmpty {
                "Validation failed at \(error.instanceLocation) (keyword: \(error.keyword))"
            } else {
                "\(error.message) at \(error.instanceLocation)"
            }
            result.append(message)

            // Recursively flatten nested errors
            if let nested = error.errors {
                result.append(contentsOf: flattenErrors(nested))
            }
        }

        return result
    }
}
