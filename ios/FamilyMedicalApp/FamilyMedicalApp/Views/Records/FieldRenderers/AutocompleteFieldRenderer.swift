import SwiftUI

/// Renders a TextField with a dropdown of suggestions filtered by the user's input.
///
/// Supports two modes:
/// - **Catalog autocomplete** (`autocompleteSource` is set): suggests values from bundled
///   data (vaccines, medications, observation types).
/// - **Provider autocomplete** (keyPath is "providerId"): suggests Providers loaded via
///   `viewModel.providers`, storing the selected provider's UUID.
struct AutocompleteFieldRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel
    @State private var queryText: String = ""
    @State private var showingSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metadata.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if metadata.isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            TextField(metadata.placeholder ?? "", text: $queryText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .accessibilityLabel(metadata.displayName)
                .onChange(of: queryText) { _, newValue in
                    handleQueryChange(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    showingSuggestions = focused
                }
                .onAppear {
                    queryText = displayTextFromViewModel()
                }

            if showingSuggestions, !filteredSuggestions.isEmpty {
                suggestionsList
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredSuggestions.prefix(5), id: \.id) { suggestion in
                Button {
                    select(suggestion)
                } label: {
                    Text(suggestion.label)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
    }

    // MARK: - Suggestions

    /// Unified suggestion model: label for display, underlying identity (UUID for providers,
    /// String for catalog entries).
    private struct Suggestion: Identifiable {
        let id: String
        let label: String
        let providerId: UUID?
    }

    private var filteredSuggestions: [Suggestion] {
        if metadata.keyPath == "providerId" {
            let matches: [Provider]
            if queryText.isEmpty {
                matches = viewModel.providers
            } else {
                let lowered = queryText.lowercased()
                matches = viewModel.providers.filter {
                    ($0.name?.lowercased().contains(lowered) ?? false) ||
                        ($0.organization?.lowercased().contains(lowered) ?? false)
                }
            }
            return matches.map { Suggestion(id: $0.id.uuidString, label: $0.displayString, providerId: $0.id) }
        }
        if let source = metadata.autocompleteSource {
            return viewModel.autocompleteService
                .suggestions(for: source, query: queryText)
                .map { Suggestion(id: $0, label: $0, providerId: nil) }
        }
        return []
    }

    private func handleQueryChange(_ newValue: String) {
        showingSuggestions = isFocused
        // For catalog fields, the query text IS the stored value.
        // For providerId, only select() stores the UUID — typing alone clears any selection.
        if metadata.keyPath == "providerId" {
            if newValue.isEmpty {
                viewModel.setValue(nil, for: metadata.keyPath)
            }
            return
        }
        viewModel.setValue(newValue.isEmpty ? nil : newValue, for: metadata.keyPath)
    }

    private func select(_ suggestion: Suggestion) {
        if let providerId = suggestion.providerId {
            viewModel.setValue(providerId, for: metadata.keyPath)
        } else {
            viewModel.setValue(suggestion.label, for: metadata.keyPath)
        }
        queryText = suggestion.label
        showingSuggestions = false
        isFocused = false
    }

    private func displayTextFromViewModel() -> String {
        if metadata.keyPath == "providerId" {
            guard let uuid = viewModel.uuidValue(for: metadata.keyPath),
                  let provider = viewModel.providers.first(where: { $0.id == uuid })
            else { return "" }
            return provider.displayString
        }
        return viewModel.stringValue(for: metadata.keyPath)
    }
}
