import SwiftUI

/// View for executing a schema migration
struct SchemaMigrationView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel: SchemaMigrationViewModel
    @State private var showingConfirmation = false

    let onComplete: (() -> Void)?

    // MARK: - Initialization

    init(
        person: Person,
        migration: SchemaMigration,
        onComplete: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: SchemaMigrationViewModel(
            person: person,
            migration: migration
        ))
        self.onComplete = onComplete
    }

    /// Test-only initializer that accepts a pre-configured ViewModel
    init(viewModel: SchemaMigrationViewModel, onComplete: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(viewModel.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .disabled(viewModel.phase == .migrating)
                    }
                }
                .confirmationDialog(
                    "Confirm Migration",
                    isPresented: $showingConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Migrate Records") {
                        Task {
                            await viewModel.executeMigration()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if let preview = viewModel.preview {
                        Text("This will migrate \(preview.recordCount) records. This action cannot be undone.")
                    }
                }
                .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && viewModel.phase == .failed)) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
                .onChange(of: viewModel.didComplete) { _, didComplete in
                    if didComplete {
                        onComplete?()
                        dismiss()
                    }
                }
                .task {
                    if viewModel.phase == .idle {
                        await viewModel.loadPreview()
                    }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .idle, .loadingPreview:
            loadingView
        case .showingPreview:
            previewView
        case .confirming:
            previewView
        case .migrating:
            progressView
        case .completed:
            completedView
        case .failed:
            failedView
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            Text("Loading preview...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview View

    private var previewView: some View {
        Form {
            Section {
                if let preview = viewModel.preview {
                    LabeledContent("Records to migrate") {
                        Text("\(preview.recordCount)")
                            .foregroundColor(preview.recordCount > 0 ? .primary : .secondary)
                    }
                }
            } header: {
                Text("Migration Summary")
            }

            if let preview = viewModel.preview, !preview.warnings.isEmpty {
                Section {
                    ForEach(preview.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                } header: {
                    Text("Warnings")
                }
            }

            if viewModel.hasMerges {
                Section {
                    Picker("Merge strategy", selection: $viewModel.mergeStrategy) {
                        Text("Concatenate").tag(MergeStrategy.concatenate(separator: " "))
                        Text("Prefer source").tag(MergeStrategy.preferSource)
                        Text("Prefer target").tag(MergeStrategy.preferTarget)
                    }
                    .pickerStyle(.menu)

                    if case .concatenate = viewModel.mergeStrategy {
                        TextField("Separator", text: $viewModel.concatenateSeparator)
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("Merge Options")
                } footer: {
                    Text("Prefer source uses merged values. Prefer target keeps existing value if present.")
                }
            }

            Section {
                Button {
                    showingConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Start Migration")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(viewModel.preview?.recordCount == 0)
            }
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.progress?.progress ?? 0) {
                Text("Migrating records...")
                    .font(.headline)
            } currentValueLabel: {
                if let progress = viewModel.progress {
                    Text("\(progress.processedRecords) of \(progress.totalRecords)")
                        .foregroundColor(.secondary)
                }
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 32)

            Text("Please wait. Do not close the app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Migration Complete")
                .font(.title2)
                .fontWeight(.semibold)

            if let result = viewModel.result {
                VStack(spacing: 8) {
                    Text("\(result.recordsSucceeded) records migrated successfully")
                        .foregroundColor(.secondary)

                    if result.recordsFailed > 0 {
                        Text("\(result.recordsFailed) records failed")
                            .foregroundColor(.red)
                    }

                    Text("Duration: \(String(format: "%.1f", result.duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button("Done") {
                onComplete?()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Migration Failed")
                .font(.title2)
                .fontWeight(.semibold)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let result = viewModel.result, !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.errors.prefix(5), id: \.recordId) { error in
                        Text("• \(error.reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if result.errors.count > 5 {
                        Text("... and \(result.errors.count - 5) more errors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
            }

            HStack(spacing: 16) {
                Button("Try Again") {
                    viewModel.reset()
                    Task {
                        await viewModel.loadPreview()
                    }
                }
                .buttonStyle(.bordered)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
