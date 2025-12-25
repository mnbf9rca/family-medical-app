import SwiftUI

struct SecuritySettingsView: View {
    @State private var viewModel = SecuritySettingsViewModel()
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        Form {
            // Biometric section
            if viewModel.isBiometricAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.isBiometricEnabled },
                        set: { _ in
                            Task {
                                await viewModel.toggleBiometric()
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: viewModel.biometryType == .faceID ? "faceid" : "touchid")
                            Text("Use \(viewModel.biometryType == .faceID ? "Face ID" : "Touch ID")")
                        }
                    }
                    .disabled(viewModel.isLoading)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Biometric Authentication")
                }
            }

            // Lock timeout section
            Section {
                Picker("Auto-Lock Timeout", selection: $viewModel.lockTimeoutMinutes) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
            } header: {
                Text("Security")
            } footer: {
                Text("App will automatically lock after being in the background for this duration")
            }
        }
        .navigationTitle("Security Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
