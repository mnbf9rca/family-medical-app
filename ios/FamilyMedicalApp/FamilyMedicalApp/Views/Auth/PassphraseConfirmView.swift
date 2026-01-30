import SwiftUI

/// Fourth step for new users: confirm the passphrase
///
/// User must re-enter their passphrase to confirm it matches.
/// On success, progresses to BiometricSetupView.
struct PassphraseConfirmView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let username: String
    let passphrase: String

    @FocusState private var isConfirmFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            // Back button at top left
            HStack {
                Button {
                    viewModel.goBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .foregroundColor(.blue)
                .accessibilityIdentifier("backButton")

                Spacer()
            }

            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("Confirm Passphrase")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Please enter your passphrase again to confirm.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Confirmation input section
            VStack(spacing: 20) {
                // Confirm passphrase field
                Group {
                    if UITestingHelpers.isUITesting {
                        TextField("Confirm passphrase", text: $viewModel.confirmPassphrase)
                    } else {
                        SecureField("Confirm passphrase", text: $viewModel.confirmPassphrase)
                    }
                }
                .textContentType(.password)
                .focused($isConfirmFocused)
                .submitLabel(.continue)
                .onSubmit { confirmPassphrase() }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .accessibilityIdentifier("confirmPassphraseField")

                // Mismatch indicator
                if !viewModel.confirmPassphrase.isEmpty, viewModel.confirmPassphrase != passphrase {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Passphrases don't match")
                            .foregroundColor(.red)
                    }
                    .font(.callout)
                    .accessibilityIdentifier("mismatchLabel")
                }

                // Match indicator
                if !viewModel.confirmPassphrase.isEmpty, viewModel.confirmPassphrase == passphrase {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Passphrases match")
                            .foregroundColor(.green)
                    }
                    .font(.callout)
                    .accessibilityIdentifier("matchLabel")
                }

                // Continue button
                Button(action: confirmPassphrase) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.confirmPassphrase == passphrase && !viewModel.confirmPassphrase.isEmpty
                    ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.confirmPassphrase != passphrase || viewModel.confirmPassphrase.isEmpty || viewModel
                    .isLoading)
                .accessibilityIdentifier("continueButton")

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
        }
        .padding()
        .onAppear {
            isConfirmFocused = true
        }
    }

    private func confirmPassphrase() {
        Task {
            await viewModel.submitPassphraseConfirmation()
        }
    }
}

#Preview {
    PassphraseConfirmView(
        viewModel: AuthenticationViewModel(),
        username: "testuser",
        passphrase: "test-passphrase-123"
    )
}
