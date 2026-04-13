import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Test mock for OrphanBlobCleanupServiceProtocol.
///
/// Records calls and returns pre-configured `CleanupResult`s or throws pre-configured
/// errors. Used by Task 6's Settings UI wiring (dry-run + confirmation dialog) and any
/// future launch-time cleanup wiring in Task 7.
final class MockOrphanBlobCleanupService: OrphanBlobCleanupServiceProtocol, @unchecked Sendable {
    // MARK: - Call Tracking

    var cleanOrphansCalls: [UUID] = []
    var countOrphansCalls: [UUID] = []

    // MARK: - Result / Error Stubs

    var cleanOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)
    var countOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)
    var cleanOrphansError: Error?
    var countOrphansError: Error?

    // MARK: - Test Helpers

    /// Resets all call records and stubs to their default values. Use between test cases
    /// that share a single mock instance.
    func reset() {
        cleanOrphansCalls.removeAll()
        countOrphansCalls.removeAll()
        cleanOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)
        countOrphansResult = CleanupResult(orphanCount: 0, freedBytes: 0)
        cleanOrphansError = nil
        countOrphansError = nil
    }

    // MARK: - OrphanBlobCleanupServiceProtocol

    func cleanOrphans(personId: UUID, primaryKey _: SymmetricKey) async throws -> CleanupResult {
        cleanOrphansCalls.append(personId)
        if let cleanOrphansError {
            throw cleanOrphansError
        }
        return cleanOrphansResult
    }

    func countOrphans(personId: UUID, primaryKey _: SymmetricKey) async throws -> CleanupResult {
        countOrphansCalls.append(personId)
        if let countOrphansError {
            throw countOrphansError
        }
        return countOrphansResult
    }
}
