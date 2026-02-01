import Foundation

/// Simple error for missing data field
private struct MissingDataFieldError: Error, LocalizedError {
    var errorDescription: String? {
        "Backup file has no data field"
    }
}

/// Error types for demo data loading
enum DemoDataLoaderError: Error, LocalizedError {
    case fileNotFound
    case decodingFailed(Error)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "Demo data file not found in bundle"
        case let .decodingFailed(error):
            "Failed to decode demo data: \(error.localizedDescription)"
        case .checksumMismatch:
            "Demo data checksum verification failed"
        }
    }
}

/// Protocol for loading bundled demo data
protocol DemoDataLoaderProtocol: Sendable {
    /// Load demo data from bundled JSON file
    func loadDemoData() throws -> BackupPayload
}

/// Loads demo data from the bundled demo-data.json file
final class DemoDataLoader: DemoDataLoaderProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let bundle: Bundle

    // MARK: - Initialization

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    // MARK: - DemoDataLoaderProtocol

    func loadDemoData() throws -> BackupPayload {
        // Find bundled file
        guard let url = bundle.url(forResource: "demo-data", withExtension: "json") else {
            throw DemoDataLoaderError.fileNotFound
        }

        // Load file data
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DemoDataLoaderError.decodingFailed(error)
        }

        // Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupFile: BackupFile
        do {
            backupFile = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw DemoDataLoaderError.decodingFailed(error)
        }

        // For unencrypted backup, data is directly available
        guard let payload = backupFile.data else {
            throw DemoDataLoaderError.decodingFailed(MissingDataFieldError())
        }

        return payload
    }
}
