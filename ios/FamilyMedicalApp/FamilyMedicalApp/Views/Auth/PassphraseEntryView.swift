import SwiftUI

/// Alternative step for returning users: enter existing passphrase
///
/// When a user indicates they are returning (via username entry),
/// they enter their existing passphrase instead of creating a new one.
struct PassphraseEntryView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let username: String

    @FocusState private var isPassphraseFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.key")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your passphrase to access your data on this device.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

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
                .textContentType(.password)
                .focused($isPassphraseFocused)
                .submitLabel(.continue)
                .onSubmit { submitPassphrase() }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .accessibilityIdentifier("passphraseField")

                // Continue button
                Button(action: submitPassphrase) {
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
                .background(!viewModel.passphrase.isEmpty ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.passphrase.isEmpty || viewModel.isLoading)
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

    private func submitPassphrase() {
        Task {
            await viewModel.submitExistingPassphrase()
        }
    }
}

#Preview {
    PassphraseEntryView(
        viewModel: AuthenticationViewModel(),
        username: "testuser"
    )
}
