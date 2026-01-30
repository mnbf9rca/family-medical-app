import CoreData
import Foundation

/// Protocol for Core Data stack operations
protocol CoreDataStackProtocol: Sendable {
    /// Main queue context for UI operations
    var viewContext: NSManagedObjectContext { get }

    /// Create a new background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext

    /// Perform an async task with a background context
    /// - Parameter block: The task to perform, receives a background context
    /// - Returns: The result of the task
    /// - Throws: Any error thrown by the task
    func performBackgroundTask<T>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T
}

/// Core Data stack for encrypted medical records storage
final class CoreDataStack: CoreDataStackProtocol, @unchecked Sendable {
    // MARK: - Singleton

    static let shared = CoreDataStack()

    // MARK: - Properties

    private let container: NSPersistentContainer

    /// @unchecked Sendable: NSPersistentContainer is thread-safe per Apple documentation.
    /// viewContext is confined to main queue via @MainActor in protocol consumers.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Initialization

    /// Initialize Core Data stack
    /// - Parameter inMemory: If true, uses in-memory store (for testing)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FamilyMedicalApp")

        if inMemory {
            // In-memory store for tests
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                // In production, this is a fatal error - app cannot function without Core Data
                // In tests, this will fail the test immediately
                fatalError("Failed to load Core Data store: \(error.localizedDescription)")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // MARK: - CoreDataStackProtocol

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Testing Support

    /// Delete all data from Core Data (for testing only)
    /// - Throws: Error if deletion fails
    func deleteAllData() async throws {
        try await performBackgroundTask { context in
            // Get all entity names from the model
            guard let entities = self.container.managedObjectModel.entities.compactMap(\.name) as [String]? else {
                return
            }

            // Delete all objects for each entity
            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
            }

            // Save changes
            try context.save()

            // Reset contexts
            context.reset()
        }

        // Also reset view context on main thread
        await MainActor.run {
            viewContext.reset()
        }
    }

    /// Synchronously delete all data from Core Data (for testing only, called from app init)
    /// - Throws: Error if deletion fails
    func deleteAllDataSync() throws {
        let context = container.newBackgroundContext()

        // nonisolated(unsafe): performAndWait is synchronous and blocks until completion,
        // so this variable access is actually safe despite the compiler not being able to prove it.
        nonisolated(unsafe) var thrownError: Error?

        context.performAndWait {
            do {
                // Get all entity names from the model
                guard let entities = container.managedObjectModel.entities.compactMap(\.name) as [String]? else {
                    return
                }

                // Delete all objects for each entity
                for entityName in entities {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try context.execute(deleteRequest)
                }

                // Save changes
                try context.save()

                // Reset contexts
                context.reset()
                viewContext.reset()
            } catch {
                thrownError = error
            }
        }

        if let error = thrownError {
            throw error
        }
    }
}
