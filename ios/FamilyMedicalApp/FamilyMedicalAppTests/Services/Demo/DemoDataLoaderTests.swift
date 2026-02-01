import Foundation
import Testing
@testable import FamilyMedicalApp

struct DemoDataLoaderTests {
    // MARK: - Load Demo Data Tests

    @Test
    func loadDemoDataReturnsBackupPayload() throws {
        let loader = DemoDataLoader()

        let payload = try loader.loadDemoData()

        #expect(payload.persons.count == 3)
        #expect(payload.persons[0].name == "Alex Johnson")
    }

    @Test
    func loadDemoDataHasExpectedPersonIds() throws {
        let loader = DemoDataLoader()

        let payload = try loader.loadDemoData()

        #expect(payload.persons[0].id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(payload.persons[1].id == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(payload.persons[2].id == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
    }

    @Test
    func loadDemoDataHasExpectedLabels() throws {
        let loader = DemoDataLoader()

        let payload = try loader.loadDemoData()

        #expect(payload.persons[0].labels == ["Self"])
        #expect(payload.persons[1].labels == ["Spouse", "Household Member"])
        #expect(payload.persons[2].labels == ["Child", "Dependent"])
    }

    // MARK: - Error Cases

    @Test
    func loadDemoDataThrowsFileNotFoundForInvalidBundle() {
        // Create a loader with an empty bundle that won't have the demo file
        let emptyBundle = Bundle(for: EmptyBundleClass.self)
        let loader = DemoDataLoader(bundle: emptyBundle)

        do {
            _ = try loader.loadDemoData()
            Issue.record("Expected fileNotFound error to be thrown")
        } catch let error as DemoDataLoaderError {
            if case .fileNotFound = error {
                // Success - expected error was thrown
            } else {
                Issue.record("Expected fileNotFound, got different DemoDataLoaderError: \(error)")
            }
        } catch {
            Issue.record("Expected DemoDataLoaderError.fileNotFound, got: \(error)")
        }
    }

    // MARK: - Error Description Tests

    @Test
    func fileNotFoundErrorDescriptionIsCorrect() {
        let error = DemoDataLoaderError.fileNotFound

        #expect(error.errorDescription == "Demo data file not found in bundle")
    }

    @Test
    func decodingFailedErrorDescriptionIncludesUnderlyingError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid JSON"
        ])
        let error = DemoDataLoaderError.decodingFailed(underlyingError)

        #expect(error.errorDescription == "Failed to decode demo data: Invalid JSON")
    }

    @Test
    func checksumMismatchErrorDescriptionIsCorrect() {
        let error = DemoDataLoaderError.checksumMismatch

        #expect(error.errorDescription == "Demo data checksum verification failed")
    }

    // MARK: - Error Case Tests

    @Test
    func decodingFailedContainsUnderlyingError() {
        let underlyingError = NSError(domain: "test", code: 42)
        let error = DemoDataLoaderError.decodingFailed(underlyingError)

        if case let .decodingFailed(contained) = error {
            let nsError = contained as NSError
            #expect(nsError.domain == "test")
            #expect(nsError.code == 42)
        } else {
            Issue.record("Expected decodingFailed case")
        }
    }

    @Test
    func fileNotFoundCaseMatches() {
        let error = DemoDataLoaderError.fileNotFound

        if case .fileNotFound = error {
            // Success
        } else {
            Issue.record("Expected fileNotFound case")
        }
    }

    @Test
    func checksumMismatchCaseMatches() {
        let error = DemoDataLoaderError.checksumMismatch

        if case .checksumMismatch = error {
            // Success
        } else {
            Issue.record("Expected checksumMismatch case")
        }
    }
}

// MARK: - Helper for Empty Bundle Test

/// Empty class to get a bundle that doesn't contain demo-data.json
private final class EmptyBundleClass {}
