import CryptoKit
import Foundation
import Observation

/// ViewModel for executing a schema migration
@MainActor
@Observable
final class SchemaMigrationViewModel {
    // MARK: - State

    let person: Person
    let migration: SchemaMigration

    /// Preview of the migration (populated after loadPreview)
    var preview: MigrationPreview?

    /// Progress during migration execution
    var progress: MigrationProgress?

    /// Result after migration completes
    var result: MigrationResult?

    /// Current phase of the migration UI
    var phase: ViewPhase = .idle

    /// User-configurable merge strategy
    var mergeStrategy: MergeStrategy = .concatenate(separator: " ")

    /// Custom separator for concatenation
    var concatenateSeparator: String = " "

    /// Loading state
    var isLoading = false

    /// Error message to display
    var errorMessage: String?

    /// Whether the migration completed successfully
    var didComplete = false

    // MARK: - View Phases

    enum ViewPhase: Equatable {
        case idle
        case loadingPreview
        case showingPreview
        case confirming
        case migrating
        case completed
        case failed
    }

    // MARK: - Dependencies

    private let migrationService: SchemaMigrationServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Computed Properties

    /// Whether this migration includes merge transformations
    var hasMerges: Bool {
        migration.hasMerges
    }

    /// Whether this migration includes type conversions
    var hasTypeConversions: Bool {
        migration.hasTypeConversions
    }

    /// The current merge strategy (updated when separator changes)
    var currentMergeStrategy: MergeStrategy {
        .concatenate(separator: concatenateSeparator)
    }

    /// Title for the migration view
    var title: String {
        "Migrate \(migration.schemaId)"
    }

    // MARK: - Initialization

    /// Initialize the migration ViewModel
    ///
    /// - Parameters:
    ///   - person: The person whose records to migrate
    ///   - migration: The migration to execute
    ///   - migrationService: Service (defaults to production)
    ///   - primaryKeyProvider: Provider (defaults to production)
    init(
        person: Person,
        migration: SchemaMigration,
        migrationService: SchemaMigrationServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil
    ) {
        self.person = person
        self.migration = migration

        // Use optional parameter pattern per ADR-0008
        if let migrationService {
            self.migrationService = migrationService
        } else {
            let coreDataStack = CoreDataStack.shared
            let encryptionService = EncryptionService()
            let recordContentService = RecordContentService(encryptionService: encryptionService)
            let medicalRecordRepository = MedicalRecordRepository(coreDataStack: coreDataStack)
            let checkpointService = MigrationCheckpointService(
                coreDataStack: coreDataStack,
                medicalRecordRepository: medicalRecordRepository
            )
            self.migrationService = SchemaMigrationService(
                medicalRecordRepository: medicalRecordRepository,
                recordContentService: recordContentService,
                checkpointService: checkpointService,
                fmkService: FamilyMemberKeyService()
            )
        }
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
    }

    // MARK: - Actions

    /// Load the migration preview
    func loadPreview() async {
        phase = .loadingPreview
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            preview = try await migrationService.previewMigration(
                migration,
                forPerson: person.id,
                primaryKey: primaryKey
            )
            phase = .showingPreview
        } catch {
            errorMessage = "Unable to load migration preview. Please try again."
            logger.logError(error, context: "SchemaMigrationViewModel.loadPreview")
            phase = .failed
        }

        isLoading = false
    }

    /// Execute the migration
    func executeMigration() async {
        phase = .migrating
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let options = MigrationOptions(
                mergeStrategy: currentMergeStrategy
            )

            result = try await migrationService.executeMigration(
                migration,
                forPerson: person.id,
                primaryKey: primaryKey,
                options: options
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.progress = progress
                }
            }

            if let result, result.isSuccess {
                phase = .completed
                didComplete = true
            } else {
                phase = .failed
                if let result, !result.errors.isEmpty {
                    errorMessage = "Migration completed with \(result.recordsFailed) errors."
                }
            }
        } catch {
            errorMessage = "Migration failed: \(error.localizedDescription)"
            logger.logError(error, context: "SchemaMigrationViewModel.executeMigration")
            phase = .failed
        }

        isLoading = false
    }

    /// Reset the view to try again
    func reset() {
        phase = .idle
        preview = nil
        progress = nil
        result = nil
        errorMessage = nil
        didComplete = false
    }
}
