import Foundation
@testable import FamilyMedicalApp

/// Shared test helpers for creating Provider fixtures across test files.
enum ProviderTestHelper {
    /// Creates a test Provider with configurable properties.
    ///
    /// - Parameters:
    ///   - name: Provider name. Defaults to "Dr. Smith".
    ///   - organization: Optional organization. Defaults to nil.
    ///   - specialty: Optional specialty. Defaults to "Cardiology".
    ///   - phone: Optional phone. Defaults to "555-0100".
    ///   - address: Optional address. Defaults to "123 Main St".
    ///   - notes: Optional notes. Defaults to "Great doctor".
    /// - Returns: A test Provider instance.
    static func makeProvider(
        name: String? = "Dr. Smith",
        organization: String? = nil,
        specialty: String? = "Cardiology",
        phone: String? = "555-0100",
        address: String? = "123 Main St",
        notes: String? = "Great doctor"
    ) -> Provider {
        Provider(
            name: name,
            organization: organization,
            specialty: specialty,
            phone: phone,
            address: address,
            notes: notes
        )
    }
}
