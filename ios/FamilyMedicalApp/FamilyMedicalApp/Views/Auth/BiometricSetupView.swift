import SwiftUI

/// Final step: optional biometric setup
///
/// Both new users and returning users see this after passphrase setup/entry.
/// Allows enabling Face ID or Touch ID for convenient daily unlock.
struct BiometricSetupView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let email: String
    let passphrase: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: viewModel.biometryType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("Enable \(biometryName)?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Use \(biometryName) to quickly unlock the app without entering your passphrase each time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                // Enable biometric button
                Button(action: {
                    Task {
                        await viewModel.completeSetup(enableBiometric: true)
                    }
                }, label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Enable \(biometryName)")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                })
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.isLoading || !viewModel.isBiometricAvailable)
                .accessibilityIdentifier("enableBiometricButton")

                // Skip button
                Button(action: {
                    Task {
                        await viewModel.completeSetup(enableBiometric: false)
                    }
                }, label: {
                    Text("Skip for now")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                })
                .foregroundColor(.blue)
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("skipButton")

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("errorLabel")
                }
            }
            .padding()

            Spacer()

            // Back button
            Button(action: {
                viewModel.goBack()
            }, label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.blue)
            })
            .accessibilityIdentifier("backButton")
            .padding(.bottom)
        }
        .padding()
    }

    private var biometryName: String {
        switch viewModel.biometryType {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        case .none:
            "Biometric"
        }
    }
}

#Preview {
    BiometricSetupView(
        viewModel: AuthenticationViewModel(),
        email: "test@example.com",
        passphrase: "test-passphrase-123"
    )
}
