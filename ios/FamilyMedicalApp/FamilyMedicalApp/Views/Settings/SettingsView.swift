import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

/// Main settings view with backup export/import functionality
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let primaryKey: SymmetricKey

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                backupSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingExportOptions) {
                ExportOptionsSheet(viewModel: viewModel, primaryKey: primaryKey)
            }
            .sheet(isPresented: $viewModel.showingFilePicker) {
                BackupFilePickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingImportPassword) {
                ImportPasswordSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingImportPreview) {
                ImportPreviewSheet(viewModel: viewModel, primaryKey: primaryKey)
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let data = viewModel.exportedFileData {
                    BackupShareSheet(
                        items: [BackupFileItem(data: data, fileName: viewModel.exportFileName)]
                    )
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Import Successful", isPresented: $viewModel.importCompleted) {
                Button("OK", role: .cancel) {
                    viewModel.dismissImportCompleted()
                }
            } message: {
                Text("Your data has been successfully imported.")
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                viewModel.startExport()
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }

            Button {
                viewModel.startImport()
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Export your data to a secure backup file, or restore from a previous backup.")
        }
    }
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    @Bindable var viewModel: SettingsViewModel
    let primaryKey: SymmetricKey
    @Environment(\.dismiss)
    private var dismiss
    @FocusState private var passwordFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                encryptionSection
                if viewModel.exportEncrypted {
                    passwordSection
                }
                exportButtonSection
            }
            .navigationTitle("Export Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetExportState()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Export Without Encryption?",
                isPresented: $viewModel.showingUnencryptedWarning,
                titleVisibility: .visible
            ) {
                Button("Export Unencrypted", role: .destructive) {
                    viewModel.confirmUnencryptedExport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("""
                Your backup will contain all your medical records in readable format.

                Anyone with access to this file can read your data.

                Only choose this if you're storing in an already-encrypted location.
                """)
            }
        }
    }

    private var encryptionSection: some View {
        Section {
            Toggle("Encrypt Backup", isOn: Binding(
                get: { viewModel.exportEncrypted },
                set: { newValue in
                    if newValue {
                        viewModel.exportEncrypted = true
                    } else {
                        viewModel.requestUnencryptedExport()
                    }
                }
            ))
        } footer: {
            Text("Encryption protects your medical data with a password.")
        }
    }

    private var passwordSection: some View {
        Section {
            SecureField("Password", text: $viewModel.exportPassword)
                .textContentType(.newPassword)
                .focused($passwordFieldFocused)
                .accessibilityIdentifier("exportPasswordField")

            SecureField("Confirm Password", text: $viewModel.exportConfirmPassword)
                .textContentType(.newPassword)
                .accessibilityIdentifier("exportConfirmPasswordField")

            if !viewModel.exportPassword.isEmpty {
                PasswordStrengthIndicator(strength: viewModel.passwordStrength)
            }

            if !viewModel.exportPassword.isEmpty,
               !viewModel.exportConfirmPassword.isEmpty,
               viewModel.exportPassword != viewModel.exportConfirmPassword {
                Text("Passwords do not match")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text("Backup Password")
        } footer: {
            Text("Choose a strong password. You'll need it to restore this backup.")
        }
    }

    private var exportButtonSection: some View {
        Section {
            Button {
                Task {
                    await viewModel.performExport(primaryKey: primaryKey)
                }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isExporting {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Exporting...")
                    } else {
                        Text("Export")
                    }
                    Spacer()
                }
            }
            .disabled(!viewModel.canExport || viewModel.isExporting)
            .accessibilityIdentifier("exportButton")
        }
    }
}

// MARK: - Backup File Picker

struct BackupFilePickerSheet: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        DocumentPickerRepresentable(
            allowedContentTypes: [.fmaBackup, .json],
            onDocumentsPicked: { urls in
                if let url = urls.first {
                    Task {
                        await viewModel.handleSelectedFile(url: url)
                    }
                }
            },
            onCancel: {
                viewModel.showingFilePicker = false
            }
        )
    }
}

// MARK: - Import Password Sheet

struct ImportPasswordSheet: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss)
    private var dismiss
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Backup Password", text: $viewModel.importPassword)
                        .textContentType(.password)
                        .focused($passwordFocused)
                        .submitLabel(.continue)
                        .onSubmit {
                            Task {
                                await viewModel.decryptAndPreview()
                            }
                        }
                        .accessibilityIdentifier("importPasswordField")
                } header: {
                    Text("Enter Password")
                } footer: {
                    Text("Enter the password used to encrypt this backup.")
                }

                Section {
                    Button {
                        Task {
                            await viewModel.decryptAndPreview()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Unlock")
                            Spacer()
                        }
                    }
                    .disabled(viewModel.importPassword.isEmpty)
                    .accessibilityIdentifier("unlockButton")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Unlock Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetImportState()
                        dismiss()
                    }
                }
            }
            .onAppear {
                passwordFocused = true
            }
        }
    }
}

// MARK: - Import Preview Sheet

struct ImportPreviewSheet: View {
    @Bindable var viewModel: SettingsViewModel
    let primaryKey: SymmetricKey
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let payload = viewModel.importPreviewPayload {
                    previewContent(payload: payload)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetImportState()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.performImport(primaryKey: primaryKey)
                        }
                    } label: {
                        if viewModel.isImporting {
                            ProgressView()
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(viewModel.isImporting)
                    .accessibilityIdentifier("confirmImportButton")
                }
            }
        }
    }

    @ViewBuilder
    private func previewContent(payload: BackupPayload) -> some View {
        Section {
            InfoRow(label: "Export Date", value: formattedDate(payload.exportedAt))
            InfoRow(label: "App Version", value: payload.appVersion)
        } header: {
            Text("Backup Info")
        }

        Section {
            InfoRow(label: "Family Members", value: "\(payload.metadata.personCount)")
            InfoRow(label: "Medical Records", value: "\(payload.metadata.recordCount)")
            InfoRow(label: "Attachments", value: "\(payload.metadata.attachmentCount)")
            InfoRow(label: "Custom Schemas", value: "\(payload.metadata.schemaCount)")
        } header: {
            Text("Contents")
        }

        Section {
            Text("Importing will add all data from this backup to your app. Existing data will not be modified.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Share Sheet

struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Backup File Item for Sharing

final class BackupFileItem: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // Write to temp file for sharing
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        return tempURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "Family Medical App Backup"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.fmaBackup.identifier
    }
}

// MARK: - UTType Extension

extension UTType {
    static let fmaBackup = UTType(exportedAs: "com.cynexia.familymedicalapp.backup")
}

// MARK: - Preview

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            exportService: PreviewExportService(),
            importService: PreviewImportService(),
            backupFileService: PreviewBackupFileService()
        ),
        primaryKey: SymmetricKey(size: .bits256)
    )
}

// MARK: - Preview Helpers

private final class PreviewExportService: ExportServiceProtocol, @unchecked Sendable {
    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 2, recordCount: 10, attachmentCount: 3, schemaCount: 1),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }
}

private final class PreviewImportService: ImportServiceProtocol, @unchecked Sendable {
    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws {}
}

private final class PreviewBackupFileService: BackupFileServiceProtocol, @unchecked Sendable {
    func createEncryptedBackup(payload: BackupPayload, password: String) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: BackupEncryption(
                algorithm: "AES-256-GCM",
                kdf: BackupKDF.defaultArgon2id,
                nonce: "test",
                tag: "test"
            ),
            ciphertext: "test",
            data: nil
        )
    }

    func createUnencryptedBackup(payload: BackupPayload) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )
    }

    func decryptBackup(file: BackupFile, password: String) throws -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }

    func readUnencryptedBackup(file: BackupFile) throws -> BackupPayload {
        file.data ?? BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }

    func verifyChecksum(file: BackupFile) throws -> Bool { true }

    func serializeToJSON(file: BackupFile) throws -> Data {
        Data("{\"test\": true}".utf8)
    }

    func deserializeFromJSON(_ data: Data) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: nil
        )
    }
}
