import Foundation

// MARK: - AutocompleteServiceProtocol

protocol AutocompleteServiceProtocol: Sendable {
    func suggestions(for source: AutocompleteSource, query: String) -> [String]
    func observationTypes() -> [ObservationTypeDefinition]
}

// MARK: - Supporting Types

struct ObservationTypeDefinition: Codable {
    let name: String
    let components: [ObservationComponentDefinition]
}

struct ObservationComponentDefinition: Codable {
    let name: String
    let defaultUnit: String
    let validUnits: [String]
}

// MARK: - AutocompleteService

final class AutocompleteService: AutocompleteServiceProtocol, Sendable {
    // MARK: - Private State

    private let vaccineNames: [String]
    private let medicationNames: [String]
    private let observationTypeDefs: [ObservationTypeDefinition]

    // MARK: - Initialization

    init(bundle: Bundle = Bundle(for: AutocompleteService.self)) {
        vaccineNames = Self.loadStringArray(from: "cvx-vaccines", bundle: bundle)
        medicationNames = Self.loadStringArray(from: "who-medications", bundle: bundle)
        observationTypeDefs = Self.loadJSON(from: "observation-types", bundle: bundle)
    }

    // MARK: - AutocompleteServiceProtocol

    /// No entry/exit tracing: called per-keystroke from SwiftUI text field,
    /// tracing would cause log spam and UI performance impact.
    func suggestions(for source: AutocompleteSource, query: String) -> [String] {
        let list: [String] = switch source {
        case .cvxVaccines:
            vaccineNames
        case .whoMedications:
            medicationNames
        case .observationTypes:
            observationTypeDefs.map(\.name)
        }
        guard !query.isEmpty else { return list }
        return list.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func observationTypes() -> [ObservationTypeDefinition] {
        observationTypeDefs
    }

    // MARK: - Private Helpers

    private static func loadStringArray(from resource: String, bundle: Bundle) -> [String] {
        guard
            let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: "Autocomplete"),
            let data = try? Data(contentsOf: url),
            let array = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return array
    }

    private static func loadJSON<T: Decodable>(from resource: String, bundle: Bundle) -> [T] {
        guard
            let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: "Autocomplete"),
            let data = try? Data(contentsOf: url),
            let array = try? JSONDecoder().decode([T].self, from: data)
        else {
            return []
        }
        return array
    }
}
