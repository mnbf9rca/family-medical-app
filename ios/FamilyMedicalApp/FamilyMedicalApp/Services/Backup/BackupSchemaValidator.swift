import Foundation
import JSONSchema

/// Typed validation errors emitted by `BackupSchemaValidator`.
enum BackupValidationError: Equatable, CustomStringConvertible {
    /// JSON could not be parsed
    case malformedJSON(String)

    /// JSON parsed but couldn't be decoded for schema validation
    case jsonDecodingFailed(String)

    /// Schema resource not bundled — fail closed
    case schemaUnavailable

    /// DoS: nesting depth exceeded
    case nestingDepthExceeded(actual: Int, max: Int)

    /// DoS: array size exceeded
    case arraySizeExceeded(actual: Int, max: Int)

    /// A JSON Schema keyword failed
    case schemaViolation(keyword: String, path: String, message: String)

    var description: String {
        switch self {
        case let .malformedJSON(detail):
            "Invalid JSON: \(detail)"
        case let .jsonDecodingFailed(detail):
            "Failed to decode JSON: \(detail)"
        case .schemaUnavailable:
            "Backup schema not available; validation cannot proceed"
        case let .nestingDepthExceeded(actual, max):
            "JSON nesting depth (\(actual)) exceeds maximum allowed (\(max))"
        case let .arraySizeExceeded(actual, max):
            "Array size (\(actual)) exceeds maximum allowed (\(max))"
        case let .schemaViolation(keyword, path, message):
            if message.isEmpty {
                "Validation failed at \(path) (keyword: \(keyword))"
            } else {
                "\(message) at \(path)"
            }
        }
    }
}

/// Result of validating JSON against the backup schema
struct BackupValidationResult: Equatable {
    /// Whether the JSON is valid according to the schema
    let isValid: Bool

    /// List of validation errors (empty if valid)
    let errors: [BackupValidationError]

    static let valid = BackupValidationResult(isValid: true, errors: [])

    static func invalid(_ errors: [BackupValidationError]) -> BackupValidationResult {
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
            logger.logError(error, context: "BackupSchemaValidator.validate")
            return .invalid([.malformedJSON(error.localizedDescription)])
        }

        // Step 2: Check DoS limits before schema validation
        let dosResult = checkDoSLimits(jsonObject)
        if !dosResult.isValid {
            logger.notice("DoS limit exceeded: \(dosResult.errors.map(\.description).joined(separator: ", "))")
            return dosResult
        }

        // Step 3: Validate against schema (fail closed if unavailable)
        guard let schema else {
            logger.error("Backup schema not available; validation cannot proceed")
            return .invalid([.schemaUnavailable])
        }

        // Convert to JSONValue for schema validation
        let jsonValue: JSONSchema.JSONValue
        do {
            jsonValue = try JSONDecoder().decode(JSONSchema.JSONValue.self, from: jsonData)
        } catch {
            logger.logError(error, context: "BackupSchemaValidator.validate")
            return .invalid([.jsonDecodingFailed(error.localizedDescription)])
        }

        // Validate against schema
        let result = schema.validate(jsonValue, at: .init())

        if result.isValid {
            logger.debug("Backup JSON validated successfully")
            return .valid
        } else {
            let errors = Self.flattenErrors(result.errors ?? [])
            logger.notice("Schema validation failed: \(errors.map(\.description).joined(separator: ", "))")
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
                logger.logError(error, context: "BackupSchemaValidator.loadSchema")
            }
        }

        // Try loading from Resources directory (flat structure)
        if let schemaURL = bundle.url(forResource: "backup-v1", withExtension: "json"),
           let schemaData = try? Data(contentsOf: schemaURL),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            do {
                return try Schema(instance: schemaString)
            } catch {
                logger.logError(error, context: "BackupSchemaValidator.loadSchema")
            }
        }

        return nil
    }

    private func checkDoSLimits(_ jsonObject: Any) -> BackupValidationResult {
        var errors: [BackupValidationError] = []

        // Check nesting depth
        let depth = calculateDepth(jsonObject)
        if depth > maxNestingDepth {
            errors.append(.nestingDepthExceeded(actual: depth, max: maxNestingDepth))
        }

        // Check array sizes
        let maxFoundArraySize = findMaxArraySize(jsonObject)
        if maxFoundArraySize > maxArraySize {
            errors.append(.arraySizeExceeded(actual: maxFoundArraySize, max: maxArraySize))
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

    /// Flatten nested validation errors into typed `BackupValidationError` values
    private static func flattenErrors(_ errors: [ValidationError]) -> [BackupValidationError] {
        var result: [BackupValidationError] = []

        for error in errors {
            result.append(.schemaViolation(
                keyword: error.keyword,
                path: error.instanceLocation.description,
                message: error.message
            ))

            // Recursively flatten nested errors
            if let nested = error.errors {
                result.append(contentsOf: flattenErrors(nested))
            }
        }

        return result
    }
}
