import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Mock

private final class MockAutocompleteService: AutocompleteServiceProtocol {
    let vaccines: [String] = ["BCG (Tuberculosis)", "Hepatitis A", "Hepatitis B", "Influenza (Flu)"]
    let medications: [String] = ["Amoxicillin", "Ibuprofen", "Paracetamol", "Warfarin"]
    let obsDefs: [ObservationTypeDefinition] = [
        ObservationTypeDefinition(
            name: "Weight",
            components: [
                ObservationComponentDefinition(name: "Weight", defaultUnit: "kg", validUnits: ["kg", "lb"])
            ]
        ),
        ObservationTypeDefinition(
            name: "Blood Pressure",
            components: [
                ObservationComponentDefinition(
                    name: "Systolic",
                    defaultUnit: "mmHg",
                    validUnits: ["mmHg"]
                ),
                ObservationComponentDefinition(
                    name: "Diastolic",
                    defaultUnit: "mmHg",
                    validUnits: ["mmHg"]
                )
            ]
        )
    ]

    func suggestions(for source: AutocompleteSource, query: String) -> [String] {
        let list: [String] = switch source {
        case .cvxVaccines:
            vaccines
        case .whoMedications:
            medications
        case .observationTypes:
            obsDefs.map(\.name)
        }
        guard !query.isEmpty else { return list }
        return list.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func observationTypes() -> [ObservationTypeDefinition] {
        obsDefs
    }
}

// MARK: - Tests

@Suite("AutocompleteService Tests")
struct AutocompleteServiceTests {
    private let service = MockAutocompleteService()

    // MARK: - Empty Query

    @Test("Empty query returns full vaccine list")
    func emptyQueryReturnsFullVaccineList() {
        let results = service.suggestions(for: .cvxVaccines, query: "")
        #expect(results == service.vaccines)
    }

    @Test("Empty query returns full medication list")
    func emptyQueryReturnsFullMedicationList() {
        let results = service.suggestions(for: .whoMedications, query: "")
        #expect(results == service.medications)
    }

    @Test("Empty query returns all observation type names")
    func emptyQueryReturnsAllObservationTypeNames() {
        let results = service.suggestions(for: .observationTypes, query: "")
        #expect(results == ["Weight", "Blood Pressure"])
    }

    // MARK: - Filtering

    @Test("Filtering is case-insensitive for vaccines")
    func caseInsensitiveFilteringVaccines() {
        let lower = service.suggestions(for: .cvxVaccines, query: "hepatitis")
        let upper = service.suggestions(for: .cvxVaccines, query: "HEPATITIS")
        let mixed = service.suggestions(for: .cvxVaccines, query: "Hepatitis")
        #expect(lower == upper)
        #expect(lower == mixed)
        #expect(lower.count == 2)
    }

    @Test("Filtering by partial name returns matching medications")
    func partialFilterReturnsMedications() {
        let results = service.suggestions(for: .whoMedications, query: "cillin")
        #expect(results == ["Amoxicillin"])
    }

    @Test("Filtering with no match returns empty list")
    func filterWithNoMatchReturnsEmpty() {
        let results = service.suggestions(for: .cvxVaccines, query: "xyznotavaccine")
        #expect(results.isEmpty)
    }

    @Test("Filtering observation types by name")
    func filterObservationTypes() {
        let results = service.suggestions(for: .observationTypes, query: "weight")
        #expect(results == ["Weight"])
    }

    // MARK: - Observation Types Structure

    @Test("Observation types have components")
    func observationTypesHaveComponents() {
        let types = service.observationTypes()
        #expect(!types.isEmpty)
        for obsType in types {
            #expect(!obsType.components.isEmpty)
        }
    }

    @Test("Blood Pressure has two components")
    func bloodPressureHasTwoComponents() {
        let types = service.observationTypes()
        let bp = types.first { $0.name == "Blood Pressure" }
        #expect(bp != nil)
        #expect(bp?.components.count == 2)
    }

    @Test("Observation component has defaultUnit and validUnits")
    func observationComponentHasUnits() {
        let types = service.observationTypes()
        let weight = types.first { $0.name == "Weight" }
        let component = weight?.components.first
        #expect(component?.defaultUnit == "kg")
        #expect(component?.validUnits.contains("kg") == true)
        #expect(component?.validUnits.contains("lb") == true)
    }

    // MARK: - AutocompleteSource Raw Values

    @Test("AutocompleteSource raw values match expected strings")
    func autocompleteSourceRawValues() {
        #expect(AutocompleteSource.cvxVaccines.rawValue == "cvx-vaccines")
        #expect(AutocompleteSource.whoMedications.rawValue == "who-medications")
        #expect(AutocompleteSource.observationTypes.rawValue == "observation-types")
    }
}

// MARK: - Direct AutocompleteService Tests (real bundle)

// These tests exercise AutocompleteService directly using Bundle(for: AutocompleteService.self),
// which resolves to the app bundle at test time (AutocompleteService lives in the app target).

@Suite("AutocompleteService Direct Tests")
struct AutocompleteServiceDirectTests {
    /// Using the app bundle so the JSON files in Resources/Autocomplete/ are accessible.
    private let service = AutocompleteService(bundle: Bundle(for: AutocompleteService.self))

    @Test("Loads vaccines from bundled JSON")
    func loadsBundledVaccines() {
        let results = service.suggestions(for: .cvxVaccines, query: "")
        #expect(!results.isEmpty)
        #expect(results.contains("Hepatitis A"))
        #expect(results.contains("Influenza (Flu)"))
    }

    @Test("Loads medications from bundled JSON")
    func loadsBundledMedications() {
        let results = service.suggestions(for: .whoMedications, query: "")
        #expect(!results.isEmpty)
        #expect(results.contains("Ibuprofen"))
        #expect(results.contains("Amoxicillin"))
    }

    @Test("Loads observation types from bundled JSON")
    func loadsBundledObservationTypes() {
        let types = service.observationTypes()
        #expect(!types.isEmpty)
        let names = types.map(\.name)
        #expect(names.contains("Blood Pressure"))
        #expect(names.contains("Weight"))
    }

    @Test("Observation types have valid components")
    func observationTypesHaveValidComponents() {
        let types = service.observationTypes()
        for obsType in types {
            #expect(!obsType.components.isEmpty)
            for component in obsType.components {
                #expect(!component.defaultUnit.isEmpty)
                #expect(!component.validUnits.isEmpty)
                #expect(component.validUnits.contains(component.defaultUnit))
            }
        }
    }

    @Test("Filters vaccines case-insensitively from real data")
    func filtersVaccinesCaseInsensitivelyFromRealData() {
        let lower = service.suggestions(for: .cvxVaccines, query: "covid")
        let upper = service.suggestions(for: .cvxVaccines, query: "COVID")
        #expect(!lower.isEmpty)
        #expect(lower == upper)
    }

    @Test("Returns empty list for unmatched query")
    func returnsEmptyForUnmatchedQuery() {
        let results = service.suggestions(for: .whoMedications, query: "xyzabcnotamedication")
        #expect(results.isEmpty)
    }

    @Test("Observation type suggestions filter by name")
    func observationTypeSuggestionsFilterByName() {
        let results = service.suggestions(for: .observationTypes, query: "pressure")
        #expect(results.contains("Blood Pressure"))
        #expect(!results.contains("Weight"))
    }
}
