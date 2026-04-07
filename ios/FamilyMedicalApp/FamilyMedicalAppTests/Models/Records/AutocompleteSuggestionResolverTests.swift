import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("AutocompleteSuggestionResolver")
struct AutocompleteSuggestionResolverTests {
    // MARK: - Fixtures

    private let catalogMetadata = FieldMetadata(
        keyPath: "vaccineCode",
        displayName: "Vaccine",
        fieldType: .autocomplete,
        autocompleteSource: .cvxVaccines,
        displayOrder: 1
    )

    private let providerMetadata = FieldMetadata(
        keyPath: "providerId",
        displayName: "Provider",
        fieldType: .autocomplete,
        displayOrder: 1,
        semantic: .entityReference(.provider)
    )

    private let pharmacyMetadata = FieldMetadata(
        keyPath: "pharmacyId",
        displayName: "Pharmacy",
        fieldType: .autocomplete,
        displayOrder: 7,
        semantic: .entityReference(.provider)
    )

    private let plainAutocompleteNoSource = FieldMetadata(
        keyPath: "mystery",
        displayName: "Mystery",
        fieldType: .autocomplete,
        displayOrder: 1
    )

    private func makeResolver(
        metadata: FieldMetadata,
        providers: [Provider] = [],
        stubbedSuggestions: [AutocompleteSource: [String]] = [:]
    ) -> AutocompleteSuggestionResolver {
        let stub = AutocompleteServiceStub()
        stub.stubbedSuggestions = stubbedSuggestions
        return AutocompleteSuggestionResolver(
            metadata: metadata,
            providers: providers,
            autocompleteService: stub
        )
    }

    // MARK: - Catalog suggestions

    @Test
    func catalogSuggestions_emptyQueryReturnsFullList() {
        let resolver = makeResolver(
            metadata: catalogMetadata,
            stubbedSuggestions: [.cvxVaccines: ["Pfizer", "Moderna", "Novavax"]]
        )
        let suggestions = resolver.suggestions(for: "")
        #expect(suggestions.map(\.label) == ["Pfizer", "Moderna", "Novavax"])
        #expect(suggestions.allSatisfy { $0.providerId == nil })
    }

    @Test
    func catalogSuggestions_filtersCaseInsensitively() {
        let resolver = makeResolver(
            metadata: catalogMetadata,
            stubbedSuggestions: [.cvxVaccines: ["Pfizer", "Moderna", "Novavax"]]
        )
        let suggestions = resolver.suggestions(for: "mod")
        #expect(suggestions.map(\.label) == ["Moderna"])
    }

    @Test
    func catalogSuggestions_respectsLimit() {
        let resolver = makeResolver(
            metadata: catalogMetadata,
            stubbedSuggestions: [.cvxVaccines: ["A", "B", "C", "D", "E", "F", "G"]]
        )
        let suggestions = resolver.suggestions(for: "", limit: 3)
        #expect(suggestions.count == 3)
        #expect(suggestions.map(\.label) == ["A", "B", "C"])
    }

    @Test
    func catalogSuggestions_defaultLimitIsFive() {
        let resolver = makeResolver(
            metadata: catalogMetadata,
            stubbedSuggestions: [.cvxVaccines: Array(repeating: "X", count: 20)]
        )
        #expect(resolver.suggestions(for: "").count == 5)
    }

    @Test
    func catalogSuggestions_idEqualsLabelForCatalogEntries() {
        let resolver = makeResolver(
            metadata: catalogMetadata,
            stubbedSuggestions: [.cvxVaccines: ["Pfizer"]]
        )
        let first = resolver.suggestions(for: "").first
        #expect(first?.id == "Pfizer")
        #expect(first?.label == "Pfizer")
    }

    // MARK: - Provider suggestions

    @Test
    func providerSuggestions_emptyQueryReturnsAllProviders() {
        let providers = [
            Provider(name: "Dr Smith", organization: "Mercy"),
            Provider(name: "Dr Jones", organization: "General")
        ]
        let resolver = makeResolver(metadata: providerMetadata, providers: providers)
        let suggestions = resolver.suggestions(for: "")
        #expect(suggestions.count == 2)
    }

    @Test
    func providerSuggestions_filtersByName() {
        let target = Provider(name: "Dr Smith", organization: "Mercy")
        let providers = [
            target,
            Provider(name: "Dr Jones", organization: "General")
        ]
        let resolver = makeResolver(metadata: providerMetadata, providers: providers)
        let suggestions = resolver.suggestions(for: "smith")
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.providerId == target.id)
    }

    @Test
    func providerSuggestions_filtersByOrganization() {
        let target = Provider(name: nil, organization: "Mercy Hospital")
        let providers = [
            Provider(name: "Dr Smith", organization: "General"),
            target
        ]
        let resolver = makeResolver(metadata: providerMetadata, providers: providers)
        let suggestions = resolver.suggestions(for: "mercy")
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.providerId == target.id)
    }

    @Test
    func providerSuggestions_idIsProviderUUIDString() {
        let provider = Provider(name: "Dr Smith", organization: nil)
        let resolver = makeResolver(metadata: providerMetadata, providers: [provider])
        let first = resolver.suggestions(for: "").first
        #expect(first?.id == provider.id.uuidString)
        #expect(first?.providerId == provider.id)
    }

    @Test
    func providerSuggestions_labelIsDisplayString() {
        let provider = Provider(name: "Dr Smith", organization: "Mercy")
        let resolver = makeResolver(metadata: providerMetadata, providers: [provider])
        let first = resolver.suggestions(for: "").first
        #expect(first?.label == "Dr Smith at Mercy")
    }

    // MARK: - No-source autocomplete (defensive)

    @Test
    func autocomplete_returnsEmptyWhenNoSourceAndNotProvider() {
        let resolver = makeResolver(metadata: plainAutocompleteNoSource)
        #expect(resolver.suggestions(for: "anything").isEmpty)
    }

    // MARK: - Display text

    @Test
    func displayText_providerId_returnsDisplayStringForKnownProvider() {
        let provider = Provider(name: "Dr Smith", organization: "Mercy")
        let resolver = makeResolver(metadata: providerMetadata, providers: [provider])
        let text = resolver.displayText(storedValue: provider.id)
        #expect(text == "Dr Smith at Mercy")
    }

    @Test
    func displayText_providerId_returnsEmptyWhenUUIDNotFound() {
        let resolver = makeResolver(metadata: providerMetadata, providers: [])
        let text = resolver.displayText(storedValue: UUID())
        #expect(text.isEmpty)
    }

    @Test
    func displayText_providerId_returnsEmptyForNonUUIDStoredValue() {
        let resolver = makeResolver(metadata: providerMetadata, providers: [])
        let text = resolver.displayText(storedValue: "not a uuid")
        #expect(text.isEmpty)
    }

    @Test
    func displayText_catalog_returnsStoredStringValue() {
        let resolver = makeResolver(metadata: catalogMetadata)
        let text = resolver.displayText(storedValue: "Pfizer-BioNTech COVID-19")
        #expect(text == "Pfizer-BioNTech COVID-19")
    }

    @Test
    func displayText_catalog_returnsEmptyForNilStoredValue() {
        let resolver = makeResolver(metadata: catalogMetadata)
        let text = resolver.displayText(storedValue: nil)
        #expect(text.isEmpty)
    }

    // MARK: - Pharmacy field (entity reference to provider)

    @Test
    func pharmacyField_returnsSameProviderSuggestions() {
        let providers = [
            Provider(name: "Dr Smith", organization: "Mercy"),
            Provider(name: "Dr Jones", organization: "General")
        ]
        let resolver = makeResolver(metadata: pharmacyMetadata, providers: providers)
        let suggestions = resolver.suggestions(for: "")
        #expect(suggestions.count == 2)
    }

    @Test
    func pharmacyField_filtersByProviderName() {
        let target = Provider(name: "Dr Smith", organization: "Mercy")
        let providers = [
            target,
            Provider(name: "Dr Jones", organization: "General")
        ]
        let resolver = makeResolver(metadata: pharmacyMetadata, providers: providers)
        let suggestions = resolver.suggestions(for: "smith")
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.providerId == target.id)
    }

    @Test
    func pharmacyField_displayTextResolvesUUID() {
        let provider = Provider(name: "Dr Smith", organization: "Mercy")
        let resolver = makeResolver(metadata: pharmacyMetadata, providers: [provider])
        let text = resolver.displayText(storedValue: provider.id)
        #expect(text == "Dr Smith at Mercy")
    }

    @Test
    func pharmacyField_isEntityReferenceAndProviderReference() {
        #expect(pharmacyMetadata.isEntityReference == true)
        #expect(pharmacyMetadata.isProviderReference == true)
    }
}
