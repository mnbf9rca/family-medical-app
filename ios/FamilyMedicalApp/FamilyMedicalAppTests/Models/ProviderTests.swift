import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("Provider Tests")
struct ProviderTests {
    // MARK: - Display String Tests

    @Test("Display string with name and organization")
    func displayStringBoth() {
        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
        #expect(provider.displayString == "Dr. Smith at City Hospital")
    }

    @Test("Display string with name only")
    func displayStringNameOnly() {
        let provider = Provider(name: "Dr. Smith")
        #expect(provider.displayString == "Dr. Smith")
    }

    @Test("Display string with organization only")
    func displayStringOrganizationOnly() {
        let provider = Provider(organization: "City Hospital")
        #expect(provider.displayString == "City Hospital")
    }

    // MARK: - Initialization Tests

    @Test("Init with name only succeeds")
    func initWithNameOnly() {
        let provider = Provider(name: "Dr. Smith")
        #expect(provider.name == "Dr. Smith")
        #expect(provider.organization == nil)
        #expect(provider.specialty == nil)
        #expect(provider.phone == nil)
        #expect(provider.address == nil)
        #expect(provider.notes == nil)
        #expect(provider.version == 1)
        #expect(provider.previousVersionId == nil)
    }

    @Test("Init with organization only succeeds")
    func initWithOrganizationOnly() {
        let provider = Provider(organization: "City Hospital")
        #expect(provider.organization == "City Hospital")
        #expect(provider.name == nil)
    }

    @Test("Init with all fields succeeds")
    func initWithAllFields() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000_000)
        let prevId = UUID()

        let provider = Provider(
            id: id,
            name: "Dr. Smith",
            organization: "City Hospital",
            specialty: "Cardiology",
            phone: "555-1234",
            address: "123 Main St",
            notes: "Preferred cardiologist",
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: 2,
            previousVersionId: prevId
        )

        #expect(provider.id == id)
        #expect(provider.name == "Dr. Smith")
        #expect(provider.organization == "City Hospital")
        #expect(provider.specialty == "Cardiology")
        #expect(provider.phone == "555-1234")
        #expect(provider.address == "123 Main St")
        #expect(provider.notes == "Preferred cardiologist")
        #expect(provider.createdAt == createdAt)
        #expect(provider.updatedAt == updatedAt)
        #expect(provider.version == 2)
        #expect(provider.previousVersionId == prevId)
    }

    @Test("Decoding with both name and org nil throws")
    func decodingBothNilThrows() throws {
        let json = Data("""
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "version": 1
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Provider.self, from: json)
        }
    }

    @Test("Init generates unique IDs by default")
    func initGeneratesUniqueIds() {
        let provider1 = Provider(name: "Dr. A")
        let provider2 = Provider(name: "Dr. B")
        #expect(provider1.id != provider2.id)
    }

    @Test("Init defaults version to 1")
    func initDefaultsVersionToOne() {
        let provider = Provider(name: "Dr. Smith")
        #expect(provider.version == 1)
    }

    // MARK: - Codable Tests

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let id = UUID()
        let prevId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000_000)

        let original = Provider(
            id: id,
            name: "Dr. Smith",
            organization: "City Hospital",
            specialty: "Cardiology",
            phone: "555-1234",
            address: "123 Main St",
            notes: "Preferred cardiologist",
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: 2,
            previousVersionId: prevId
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Provider.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.organization == original.organization)
        #expect(decoded.specialty == original.specialty)
        #expect(decoded.phone == original.phone)
        #expect(decoded.address == original.address)
        #expect(decoded.notes == original.notes)
        #expect(decoded.version == original.version)
        #expect(decoded.previousVersionId == original.previousVersionId)
    }

    @Test("Codable round-trip with optional fields nil")
    func codableRoundTripWithNilOptionals() throws {
        let original = Provider(name: "Dr. Smith")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Provider.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.organization == nil)
        #expect(decoded.specialty == nil)
        #expect(decoded.phone == nil)
        #expect(decoded.address == nil)
        #expect(decoded.notes == nil)
        #expect(decoded.previousVersionId == nil)
    }

    // MARK: - Identifiable Tests

    @Test("Identifiable uses id property")
    func identifiableUsesId() {
        let provider = Provider(name: "Dr. Smith")
        #expect(provider.id == provider.id) // stable identity
    }

    // MARK: - Mutation Tests

    @Test("Provider fields are mutable")
    func providerFieldsAreMutable() {
        var provider = Provider(name: "Dr. Smith")
        provider.name = "Dr. Jones"
        provider.specialty = "Oncology"
        #expect(provider.name == "Dr. Jones")
        #expect(provider.specialty == "Oncology")
    }
}
