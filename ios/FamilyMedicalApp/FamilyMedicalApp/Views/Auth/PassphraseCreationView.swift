import SwiftUI

/// Third step for new users: create a strong encryption passphrase
///
/// Displays password strength meter and validation feedback.
/// On success, progresses to PassphraseConfirmView.
struct PassphraseCreationView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let email: String

    @FocusState private var isPassphraseFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("Create a Passphrase")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This passphrase encrypts your data.\nChoose something memorable but hard to guess.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Passphrase input section
            VStack(spacing: 20) {
                // Passphrase field
                Group {
                    if UITestingHelpers.isUITesting {
                        TextField("Passphrase", text: $viewModel.passphrase)
                    } else {
                        SecureField("Passphrase", text: $viewModel.passphrase)
                    }
                }
                .textContentType(.newPassword)
                .focused($isPassphraseFocused)
                .submitLabel(.continue)
                .onSubmit { createPassphrase() }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .accessibilityIdentifier("passphraseField")

                // Strength indicator
                PasswordStrengthIndicator(strength: viewModel.passphraseStrength)
                    .accessibilityIdentifier("strengthIndicator")

                // Validation hints
                if !viewModel.passphrase.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.passphraseValidationErrors, id: \.self) { error in
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(error.errorDescription ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("validationHints")
                }

                // Continue button
                Button(action: createPassphrase) {
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
                .background(viewModel.passphraseValidationErrors.isEmpty && !viewModel.passphrase.isEmpty
                    ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!viewModel.passphraseValidationErrors.isEmpty || viewModel.passphrase.isEmpty || viewModel
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
        .onAppear {
            isPassphraseFocused = true
        }
    }

    private func createPassphrase() {
        Task {
            await viewModel.submitPassphraseCreation()
        }
    }
}

#Preview {
    PassphraseCreationView(
        viewModel: AuthenticationViewModel(),
        email: "test@example.com"
    )
}
