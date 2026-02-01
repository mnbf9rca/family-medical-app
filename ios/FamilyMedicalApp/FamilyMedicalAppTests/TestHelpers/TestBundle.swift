import Foundation

/// Helper to access the test bundle's resources
enum TestBundle {
    /// The bundle containing test resources
    /// Uses a dummy class to locate the test bundle since Swift Testing uses structs
    static let bundle: Bundle = .init(for: BundleLocator.self)
}

/// Private class used to locate the test bundle
private final class BundleLocator {}
