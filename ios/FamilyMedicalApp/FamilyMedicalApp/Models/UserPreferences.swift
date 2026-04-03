import Foundation

/// User-level preferences for the app, such as unit defaults per observation type.
///
/// Encrypted with the user's Primary Key and stored in the Keychain.
struct UserPreferences: Codable {
    /// Maps observation type identifiers to preferred unit strings.
    /// Example: ["Weight": "lb", "Temperature": "°F"]
    var unitDefaults: [String: String]

    init(unitDefaults: [String: String] = [:]) {
        self.unitDefaults = unitDefaults
    }

    /// Returns the preferred unit for a given observation type, falling back to the supplied default.
    func preferredUnit(for observationType: String, defaultUnit: String) -> String {
        unitDefaults[observationType] ?? defaultUnit
    }

    /// Stores a preferred unit for a given observation type.
    mutating func setPreferredUnit(_ unit: String, for observationType: String) {
        unitDefaults[observationType] = unit
    }
}
