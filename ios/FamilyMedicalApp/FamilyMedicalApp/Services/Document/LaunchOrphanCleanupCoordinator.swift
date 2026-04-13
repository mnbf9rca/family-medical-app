import CryptoKit
import Foundation

/// Runs orphan blob cleanup at app launch for every accessible person.
///
/// Extracted from `MainAppView.task` so the logic is testable in isolation —
/// `.task` modifiers cannot be exercised by unit tests. The coordinator is
/// best-effort and silent: failures are logged but do not surface in the UI,
/// and per-person failures never block their siblings.
final class LaunchOrphanCleanupCoordinator: Sendable {
    // MARK: - Dependencies

    private let cleanupService: OrphanBlobCleanupServiceProtocol
    private let personRepository: PersonRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(
        cleanupService: OrphanBlobCleanupServiceProtocol,
        personRepository: PersonRepositoryProtocol,
        primaryKeyProvider: PrimaryKeyProviderProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.cleanupService = cleanupService
        self.personRepository = personRepository
        self.primaryKeyProvider = primaryKeyProvider
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - Public API

    /// Run cleanup for every accessible person.
    ///
    /// Non-fatal by design: if the primary key is unavailable or `fetchAll`
    /// fails, the method logs and returns silently. If any individual person's
    /// cleanup throws, the error is logged and the sweep continues with the
    /// next person.
    ///
    /// Safe to call multiple times per process — SwiftUI's `.task` modifier
    /// re-fires on every `MainAppView` appearance (cold launch, lock → unlock,
    /// reauth), and the scan is idempotent: already-referenced blobs are
    /// skipped, already-deleted blobs are no-ops.
    func runCleanup() async {
        let start = ContinuousClock.now
        logger.entry("runCleanup")

        let primaryKey: SymmetricKey
        do {
            primaryKey = try primaryKeyProvider.getPrimaryKey()
        } catch {
            logger.exitWithError("runCleanup", error: error, duration: ContinuousClock.now - start)
            return
        }

        let persons: [Person]
        do {
            persons = try await personRepository.fetchAll(primaryKey: primaryKey)
        } catch {
            logger.exitWithError("runCleanup", error: error, duration: ContinuousClock.now - start)
            return
        }

        for person in persons {
            guard !Task.isCancelled else {
                logger.debug("Launch cleanup cancelled — aborting remaining persons")
                break
            }
            await cleanupOnePerson(person, primaryKey: primaryKey)
        }

        logger.exit("runCleanup", duration: ContinuousClock.now - start)
    }

    // MARK: - Factory

    /// Production wiring that mirrors `SettingsViewModel.DefaultDependencies`
    /// and `OrphanBlobCleanupService.makeDefault()` so the launch scanner and
    /// the writer agree on where blobs live.
    static func makeDefault() -> LaunchOrphanCleanupCoordinator {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let fmkService = FamilyMemberKeyService()
        let personRepository = PersonRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )
        return LaunchOrphanCleanupCoordinator(
            cleanupService: OrphanBlobCleanupService.makeDefault(),
            personRepository: personRepository,
            primaryKeyProvider: PrimaryKeyProvider()
        )
    }

    // MARK: - Private Helpers

    /// Run cleanup for a single person, swallowing errors so siblings can still be attempted.
    ///
    /// Extracted from `runCleanup`'s main loop to make the error-isolation boundary explicit:
    /// any throw from `cleanOrphans` is logged and absorbed here, so the outer loop always
    /// advances to the next person.
    private func cleanupOnePerson(_ person: Person, primaryKey: SymmetricKey) async {
        do {
            let result = try await cleanupService.cleanOrphans(
                personId: person.id,
                primaryKey: primaryKey
            )
            if result.orphanCount > 0 {
                logger.info(
                    "Launch cleanup for person \(person.id): removed \(result.orphanCount)" +
                        " orphan blobs, freed \(result.freedBytes) bytes"
                )
            }
        } catch {
            // One person's failure must not block siblings or the UI.
            logger.logError(error, context: "LaunchOrphanCleanupCoordinator.runCleanup.person[\(person.id)]")
        }
    }
}
