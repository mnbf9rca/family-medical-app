import SwiftUI

/// Renders a TextField with a dropdown of suggestions filtered by the user's input.
///
/// Dispatch is driven by `FieldMetadata.semantic` (not keyPath string matching):
/// - **Catalog autocomplete** (`autocompleteSource` is set): suggests values from bundled
///   data (vaccines, medications, observation types).
/// - **Entity reference** (`metadata.isEntityReference`, e.g. `.entityReference(.provider)`):
///   suggests Providers loaded via `viewModel.providers`, storing the selected entity's UUID.
///   Typing that doesn't match a resolved entity clears the stored UUID.
///
/// The business logic (filtering, display-text resolution) lives in
/// `AutocompleteSuggestionResolver` so it can be unit-tested without a view hierarchy.
struct AutocompleteFieldRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel
    @State private var queryText: String = ""
    @State private var showingSuggestions = false
    @State private var showingCreateProvider = false
    @FocusState private var isFocused: Bool

    private var resolver: AutocompleteSuggestionResolver {
        AutocompleteSuggestionResolver(
            metadata: metadata,
            providers: viewModel.providers,
            autocompleteService: viewModel.autocompleteService
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
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
                    queryText = resolver.displayText(storedValue: viewModel.value(for: metadata.keyPath))
                }
                // Providers may load after this view appears; refresh the display text
                // when they arrive so edit mode shows the provider name, not a blank field.
                // Guard: only refresh when there's a stored entity reference. Without this,
                // the providers list arriving mid-typing would wipe the user's in-progress query.
                .onChange(of: viewModel.providers) { _, _ in
                    guard viewModel.value(for: metadata.keyPath) != nil else { return }
                    queryText = resolver.displayText(storedValue: viewModel.value(for: metadata.keyPath))
                }

            if showingSuggestions {
                let suggestions = resolver.suggestions(for: queryText)
                if !suggestions.isEmpty || metadata.isProviderReference {
                    suggestionsList(suggestions)
                }
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showingCreateProvider) {
            ProviderDetailView(person: viewModel.person) { provider in
                let success = await viewModel.addProvider(provider)
                if success {
                    viewModel.setValue(provider.id, for: metadata.keyPath)
                    queryText = provider.displayString
                    showingSuggestions = false
                }
                return success
            }
        }
    }

    private var header: some View {
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
    }

    private func suggestionsList(_ suggestions: [AutocompleteSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
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
            if metadata.isProviderReference {
                Button {
                    showingCreateProvider = true
                } label: {
                    Label("Add new provider\u{2026}", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add new provider")
            }
        }
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
    }

    private func handleQueryChange(_ newValue: String) {
        showingSuggestions = isFocused
        if metadata.isEntityReference {
            // For entity-reference fields, typing alone does not store an entity UUID.
            // Clear any stored reference whenever the typed text no longer matches the
            // currently-resolved display string. Only select() commits a real reference.
            let resolvedDisplay = resolver.displayText(storedValue: viewModel.value(for: metadata.keyPath))
            if newValue != resolvedDisplay {
                viewModel.setValue(nil, for: metadata.keyPath)
            }
            return
        }
        viewModel.setValue(newValue.isEmpty ? nil : newValue, for: metadata.keyPath)
    }

    private func select(_ suggestion: AutocompleteSuggestion) {
        if let providerId = suggestion.providerId {
            viewModel.setValue(providerId, for: metadata.keyPath)
        } else {
            viewModel.setValue(suggestion.label, for: metadata.keyPath)
        }
        queryText = suggestion.label
        showingSuggestions = false
        isFocused = false
    }
}
