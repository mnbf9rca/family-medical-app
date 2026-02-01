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
    ///   - bundle: Bundle to load schema from (default: .main for app, pass test bundle for tests)
    ///   - logger: Optional logger for debug output
    init(
        maxNestingDepth: Int = 20,
        maxArraySize: Int = 100_000,
        bundle: Bundle = .main,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.maxNestingDepth = maxNestingDepth
        self.maxArraySize = maxArraySize
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)

        // Load schema from bundle
        self.schema = Self.loadSchema(from: bundle)
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

        // Step 3: Validate against schema (fail closed if unavailable)
        guard let schema else {
            let errorMessage = "Backup schema not available; validation cannot proceed"
            logger.error("\(errorMessage)")
            return .invalid([errorMessage])
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

    private static func loadSchema(from bundle: Bundle) -> Schema? {
        let logger = LoggingService.shared.logger(category: .storage)

        // Try loading from Schemas subdirectory first
        if let schemaURL = bundle.url(forResource: "backup-v1", withExtension: "json", subdirectory: "Schemas"),
           let schemaData = try? Data(contentsOf: schemaURL),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.notice("Failed to parse bundled schema: \(error.localizedDescription)")
            }
        }

        // Try loading from Resources directory (flat structure)
        if let schemaURL = bundle.url(forResource: "backup-v1", withExtension: "json"),
           let schemaData = try? Data(contentsOf: schemaURL),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.notice("Failed to parse schema from Resources: \(error.localizedDescription)")
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

    /// Calculates maximum nesting depth using iterative traversal with explicit stack.
    /// Uses early exit optimization when maxNestingDepth is exceeded.
    private func calculateDepth(_ value: Any) -> Int {
        // Stack stores tuples of (value, depth)
        var stack: [(Any, Int)] = [(value, 1)]
        var maxDepth = 1

        while let (current, depth) = stack.popLast() {
            maxDepth = max(maxDepth, depth)

            // Early exit: if we've already exceeded the limit, no need to continue
            if maxDepth > maxNestingDepth {
                return maxDepth
            }

            switch current {
            case let dict as [String: Any]:
                for child in dict.values {
                    stack.append((child, depth + 1))
                }
            case let array as [Any]:
                for child in array {
                    stack.append((child, depth + 1))
                }
            default:
                break
            }
        }

        return maxDepth
    }

    /// Finds maximum array size using iterative traversal with explicit stack.
    /// Uses early exit optimization when maxArraySize is exceeded.
    private func findMaxArraySize(_ value: Any) -> Int {
        var stack: [Any] = [value]
        var maxSize = 0

        while let current = stack.popLast() {
            switch current {
            case let dict as [String: Any]:
                for child in dict.values {
                    stack.append(child)
                }
            case let array as [Any]:
                maxSize = max(maxSize, array.count)

                // Early exit: if we've already exceeded the limit, no need to continue
                if maxSize > maxArraySize {
                    return maxSize
                }

                for child in array {
                    stack.append(child)
                }
            default:
                break
            }
        }

        return maxSize
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
