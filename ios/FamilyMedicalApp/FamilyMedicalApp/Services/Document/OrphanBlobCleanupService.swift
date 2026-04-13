import CryptoKit
import Foundation

// swiftformat:disable redundantSendable
/// Summary of an orphan blob cleanup or dry-run scan.
///
/// - `orphanCount`: number of orphan blobs counted (for `countOrphans`) or successfully
///   deleted (for `cleanOrphans`). Blobs whose size lookup or delete failed are *not*
///   included — the cleanup is best-effort and partial failures don't poison the report.
/// - `freedBytes`: bytes that will be (or were) freed by deleting those blobs.
///
/// Explicit `Sendable` conformance (instead of relying on inference) so future field
/// additions can't silently regress cross-actor use.
struct CleanupResult: Equatable, Sendable {
    let orphanCount: Int
    let freedBytes: UInt64
}

// swiftformat:enable redundantSendable

/// Scans a person's on-disk blobs, computes the set of orphans
/// (`blobsOnDisk - referencedHMACs - inFlight`), and either deletes them (`cleanOrphans`)
/// or reports the totals without touching disk (`countOrphans`).
///
/// Designed to be safe to run alongside writes: any blob currently marked in-flight by
/// `DocumentBlobService` is excluded so the cleanup scanner cannot race an active upload.
/// Partial failures (per-HMAC `blobSize` or `deleteDirect` errors) are logged and skipped
/// rather than aborting the scan — a single permission/IO blip on one file should not
/// prevent the rest of the sweep.
protocol OrphanBlobCleanupServiceProtocol: Sendable {
    /// Scan and delete orphaned blobs for a single person.
    /// - Returns: `CleanupResult` with the number of blobs successfully deleted and
    ///   the total bytes freed. Per-blob failures are logged and omitted from the tally.
    func cleanOrphans(personId: UUID, primaryKey: SymmetricKey) async throws -> CleanupResult

    /// Dry-run equivalent of `cleanOrphans` for the Settings UI confirmation dialog.
    /// Does not delete anything; returns the orphan count and bytes that *would* be freed.
    func countOrphans(personId: UUID, primaryKey: SymmetricKey) async throws -> CleanupResult
}

final class OrphanBlobCleanupService: OrphanBlobCleanupServiceProtocol, Sendable {
    private let blobService: DocumentBlobServiceProtocol
    private let queryService: DocumentReferenceQueryServiceProtocol
    private let logger: TracingCategoryLogger

    init(
        blobService: DocumentBlobServiceProtocol,
        queryService: DocumentReferenceQueryServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.blobService = blobService
        self.queryService = queryService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - OrphanBlobCleanupServiceProtocol

    func cleanOrphans(personId: UUID, primaryKey: SymmetricKey) async throws -> CleanupResult {
        let start = ContinuousClock.now
        logger.entry("cleanOrphans", "personId=\(personId)")
        do {
            let orphans = try await computeOrphans(personId: personId, primaryKey: primaryKey)
            let (count, bytes) = await sumOrphanSizes(orphans, personId: personId) { hmac in
                // Size first, delete second. If size fails, skip this HMAC and move on —
                // one bad file shouldn't abort the sweep. Same for a delete failure.
                try await self.blobService.deleteDirect(contentHMAC: hmac, personId: personId)
            }
            logger.debug("cleanOrphans deleted=\(count), freedBytes=\(bytes)")
            logger.exit("cleanOrphans", duration: ContinuousClock.now - start)
            return CleanupResult(orphanCount: count, freedBytes: bytes)
        } catch {
            logger.exitWithError("cleanOrphans", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func countOrphans(personId: UUID, primaryKey: SymmetricKey) async throws -> CleanupResult {
        let start = ContinuousClock.now
        logger.entry("countOrphans", "personId=\(personId)")
        do {
            let orphans = try await computeOrphans(personId: personId, primaryKey: primaryKey)
            // Match cleanOrphans semantics: a single unreadable file is skipped, not fatal.
            // The Settings UI would rather show an approximate count than an error for one bad blob.
            let (count, bytes) = await sumOrphanSizes(orphans, personId: personId)
            logger.debug("countOrphans count=\(count), bytes=\(bytes)")
            logger.exit("countOrphans", duration: ContinuousClock.now - start)
            return CleanupResult(orphanCount: count, freedBytes: bytes)
        } catch {
            logger.exitWithError("countOrphans", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - Factory

    /// Shared default factory for production wiring. Builds its dependencies from the
    /// same singletons used by `DocumentBlobService.makeDefault()` so the scanner and
    /// the writer agree on where blobs live.
    static func makeDefault() -> OrphanBlobCleanupService {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let recordRepository = MedicalRecordRepository(coreDataStack: coreDataStack)
        let recordContentService = RecordContentService(encryptionService: encryptionService)
        let queryService = DocumentReferenceQueryService(
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: FamilyMemberKeyService()
        )
        return OrphanBlobCleanupService(
            blobService: DocumentBlobService.makeDefault(),
            queryService: queryService
        )
    }

    // MARK: - Private

    /// Iterates `orphans`, calls `blobSize` per item (skipping failures), optionally calls a
    /// caller-supplied per-item action, and returns the `(count, bytes)` totals.
    ///
    /// This is the single source of truth for per-HMAC size accounting shared by
    /// `cleanOrphans` (which passes a `deleteDirect` action) and `countOrphans` (dry-run,
    /// no action). Keeping the loop here ensures both methods can't drift in their accounting
    /// logic.
    ///
    /// - Parameters:
    ///   - orphans: HMACs to process.
    ///   - personId: The person whose blob store is being scanned.
    ///   - performPerItem: Optional action to run on each HMAC after a successful `blobSize`.
    ///     If the action throws, the HMAC is skipped and the failure is logged but not rethrown.
    /// - Returns: `(count, bytes)` where `count` is the number of HMACs successfully processed
    ///   and `bytes` is the sum of their sizes.
    private func sumOrphanSizes(
        _ orphans: [Data],
        personId: UUID,
        performPerItem: ((Data) async throws -> Void)? = nil
    ) async -> (count: Int, bytes: UInt64) {
        var count = 0
        var bytes: UInt64 = 0
        for hmac in orphans {
            let size: UInt64
            do {
                size = try await blobService.blobSize(contentHMAC: hmac, personId: personId)
            } catch {
                logger.logError(error, context: "OrphanBlobCleanupService.sumOrphanSizes.blobSize")
                continue
            }
            if let performPerItem {
                do {
                    try await performPerItem(hmac)
                } catch {
                    logger.logError(error, context: "OrphanBlobCleanupService.sumOrphanSizes.performPerItem")
                    continue
                }
            }
            count += 1
            bytes += size
        }
        return (count, bytes)
    }

    /// Collect the orphan HMAC set for a person:
    /// `blobsOnDisk - referencedHMACs - inFlight`.
    ///
    /// In-flight filtering is async because `DocumentBlobService.isInFlight` hops the
    /// actor — this is why the function is `async` even though the set math itself isn't.
    private func computeOrphans(personId: UUID, primaryKey: SymmetricKey) async throws -> [Data] {
        let onDisk = try await blobService.listBlobs(personId: personId)
        let referenced = try await queryService.allReferencedHMACs(personId: personId, primaryKey: primaryKey)
        let unreferenced = onDisk.subtracting(referenced)

        var orphans: [Data] = []
        orphans.reserveCapacity(unreferenced.count)
        for hmac in unreferenced {
            if await blobService.isInFlight(contentHMAC: hmac) {
                continue
            }
            orphans.append(hmac)
        }
        return orphans
    }
}
