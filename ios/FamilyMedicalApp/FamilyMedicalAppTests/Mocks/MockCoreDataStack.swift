import CoreData
import Foundation
@testable import FamilyMedicalApp

/// Mock Core Data stack using in-memory store for isolated tests
/// @unchecked Sendable: Safe for tests - CoreDataStack uses in-memory store with no cross-test contamination
final class MockCoreDataStack: CoreDataStackProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let stack: CoreDataStack

    var viewContext: NSManagedObjectContext {
        stack.viewContext
    }

    // MARK: - Initialization

    /// Initialize with a unique in-memory store
    init() {
        // Use CoreDataStack with inMemory flag for testing
        stack = CoreDataStack(inMemory: true)
    }

    // MARK: - CoreDataStackProtocol

    func newBackgroundContext() -> NSManagedObjectContext {
        stack.newBackgroundContext()
    }

    func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await stack.performBackgroundTask(block)
    }
}
