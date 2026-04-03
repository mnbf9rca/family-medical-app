import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("UserPreferences Tests")
struct UserPreferencesTests {
    @Test("Default preferences have empty unit defaults")
    func defaultPreferences() {
        let prefs = UserPreferences()
        #expect(prefs.unitDefaults.isEmpty)
    }

    @Test("preferredUnit returns default when no preference set")
    func preferredUnitDefault() {
        let prefs = UserPreferences()
        #expect(prefs.preferredUnit(for: "Weight", defaultUnit: "kg") == "kg")
    }

    @Test("setPreferredUnit stores and retrieves")
    func setPreferredUnit() {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")
        #expect(prefs.preferredUnit(for: "Weight", defaultUnit: "kg") == "lb")
    }

    @Test("preferredUnit returns stored value over default")
    func preferredUnitOverridesDefault() {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("°F", for: "Temperature")
        #expect(prefs.preferredUnit(for: "Temperature", defaultUnit: "°C") == "°F")
    }

    @Test("preferredUnit falls back to default for unrelated observation type")
    func preferredUnitFallbackForOtherType() {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")
        #expect(prefs.preferredUnit(for: "Temperature", defaultUnit: "°C") == "°C")
    }

    @Test("setPreferredUnit overwrites existing entry")
    func setPreferredUnitOverwrites() {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")
        prefs.setPreferredUnit("kg", for: "Weight")
        #expect(prefs.preferredUnit(for: "Weight", defaultUnit: "lb") == "kg")
    }

    @Test("Round-trips through Codable")
    func codableRoundTrip() throws {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("°F", for: "Temperature")
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
        #expect(decoded.preferredUnit(for: "Temperature", defaultUnit: "°C") == "°F")
    }

    @Test("Codable round-trip with multiple entries")
    func codableRoundTripMultiple() throws {
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")
        prefs.setPreferredUnit("°F", for: "Temperature")
        prefs.setPreferredUnit("in", for: "Height")

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.unitDefaults.count == 3)
        #expect(decoded.preferredUnit(for: "Weight", defaultUnit: "kg") == "lb")
        #expect(decoded.preferredUnit(for: "Temperature", defaultUnit: "°C") == "°F")
        #expect(decoded.preferredUnit(for: "Height", defaultUnit: "cm") == "in")
    }

    @Test("Codable round-trip preserves empty defaults")
    func codableRoundTripEmpty() throws {
        let prefs = UserPreferences()
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
        #expect(decoded.unitDefaults.isEmpty)
    }

    @Test("Init with explicit unit defaults stores them")
    func initWithUnitDefaults() {
        let prefs = UserPreferences(unitDefaults: ["Weight": "lb", "Temperature": "°F"])
        #expect(prefs.unitDefaults.count == 2)
        #expect(prefs.preferredUnit(for: "Weight", defaultUnit: "kg") == "lb")
    }
}
