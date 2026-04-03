import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("UserPreferencesService Tests")
struct UserPreferencesServiceTests {
    // MARK: - Fixtures

    struct Fixtures {
        let service: UserPreferencesService
        let encryption: MockEncryptionService
        let keychain: MockAuthKeychainService
        let primaryKey: SymmetricKey
    }

    func makeFixtures() -> Fixtures {
        let encryption = MockEncryptionService()
        let keychain = MockAuthKeychainService()
        let primaryKey = SymmetricKey(size: .bits256)
        let service = UserPreferencesService(
            encryptionService: encryption,
            keychainService: keychain
        )
        return Fixtures(service: service, encryption: encryption, keychain: keychain, primaryKey: primaryKey)
    }

    // MARK: - load() Tests

    @Test("load returns default preferences when nothing stored")
    func loadReturnsDefaultsWhenEmpty() throws {
        let fixtures = makeFixtures()
        let prefs = try fixtures.service.load(primaryKey: fixtures.primaryKey)
        #expect(prefs.unitDefaults.isEmpty)
    }

    @Test("load returns saved preferences after save")
    func loadReturnsSavedPreferences() throws {
        let fixtures = makeFixtures()
        var original = UserPreferences()
        original.setPreferredUnit("lb", for: "Weight")

        try fixtures.service.save(original, primaryKey: fixtures.primaryKey)
        let loaded = try fixtures.service.load(primaryKey: fixtures.primaryKey)

        #expect(loaded.preferredUnit(for: "Weight", defaultUnit: "kg") == "lb")
    }

    @Test("load round-trips multiple unit defaults")
    func loadRoundTripsMultipleDefaults() throws {
        let fixtures = makeFixtures()
        var original = UserPreferences()
        original.setPreferredUnit("lb", for: "Weight")
        original.setPreferredUnit("°F", for: "Temperature")
        original.setPreferredUnit("in", for: "Height")

        try fixtures.service.save(original, primaryKey: fixtures.primaryKey)
        let loaded = try fixtures.service.load(primaryKey: fixtures.primaryKey)

        #expect(loaded.unitDefaults.count == 3)
        #expect(loaded.preferredUnit(for: "Weight", defaultUnit: "kg") == "lb")
        #expect(loaded.preferredUnit(for: "Temperature", defaultUnit: "°C") == "°F")
        #expect(loaded.preferredUnit(for: "Height", defaultUnit: "cm") == "in")
    }

    @Test("load throws on decryption failure")
    func loadThrowsOnDecryptionFailure() throws {
        let fixtures = makeFixtures()
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")

        // Save successfully first
        try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)

        // Now break decryption
        fixtures.encryption.shouldFailDecryption = true

        #expect(throws: (any Error).self) {
            try fixtures.service.load(primaryKey: fixtures.primaryKey)
        }
    }

    // MARK: - save() Tests

    @Test("save stores encrypted data in keychain")
    func saveStoresEncryptedData() throws {
        let fixtures = makeFixtures()
        let prefs = UserPreferences(unitDefaults: ["Weight": "lb"])

        try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)

        // Keychain should have data under the fixed identifier
        #expect(fixtures.keychain.dataExists(identifier: "user_preferences"))
    }

    @Test("save encrypts the data")
    func saveEncryptsData() throws {
        let fixtures = makeFixtures()
        let prefs = UserPreferences(unitDefaults: ["Weight": "lb"])

        try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)

        #expect(fixtures.encryption.encryptCalls.count == 1)
    }

    @Test("save throws on encryption failure")
    func saveThrowsOnEncryptionFailure() {
        let fixtures = makeFixtures()
        fixtures.encryption.shouldFailEncryption = true

        let prefs = UserPreferences(unitDefaults: ["Weight": "lb"])

        #expect(throws: (any Error).self) {
            try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)
        }
    }

    @Test("save overwrites previous preferences")
    func saveOverwritesPrevious() throws {
        let fixtures = makeFixtures()

        var first = UserPreferences()
        first.setPreferredUnit("lb", for: "Weight")
        try fixtures.service.save(first, primaryKey: fixtures.primaryKey)

        var second = UserPreferences()
        second.setPreferredUnit("kg", for: "Weight")
        try fixtures.service.save(second, primaryKey: fixtures.primaryKey)

        let loaded = try fixtures.service.load(primaryKey: fixtures.primaryKey)
        #expect(loaded.preferredUnit(for: "Weight", defaultUnit: "lb") == "kg")
    }

    // MARK: - delete() Tests

    @Test("delete removes stored preferences")
    func deleteRemovesStoredPreferences() throws {
        let fixtures = makeFixtures()
        let prefs = UserPreferences(unitDefaults: ["Weight": "lb"])
        try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)

        try fixtures.service.delete()

        #expect(!fixtures.keychain.dataExists(identifier: "user_preferences"))
    }

    @Test("delete is idempotent when nothing stored")
    func deleteIsIdempotentWhenEmpty() throws {
        let fixtures = makeFixtures()
        // Should not throw even though nothing is stored
        try fixtures.service.delete()
    }

    @Test("load returns defaults after delete")
    func loadReturnsDefaultsAfterDelete() throws {
        let fixtures = makeFixtures()
        var prefs = UserPreferences()
        prefs.setPreferredUnit("lb", for: "Weight")
        try fixtures.service.save(prefs, primaryKey: fixtures.primaryKey)

        try fixtures.service.delete()

        let loaded = try fixtures.service.load(primaryKey: fixtures.primaryKey)
        #expect(loaded.unitDefaults.isEmpty)
    }
}
