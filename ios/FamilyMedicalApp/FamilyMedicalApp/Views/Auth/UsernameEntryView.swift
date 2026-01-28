import SwiftUI

/// First step in the authentication flow: username entry
///
/// The user enters their username to begin OPAQUE authentication.
/// The flow continues to PassphraseCreationView for new users or
/// PassphraseEntryView for returning users.
struct UsernameEntryView: View {
    @Bindable var viewModel: AuthenticationViewModel
    @FocusState private var isUsernameFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App branding
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityLabel("Family Medical App icon")

            Text("Family Medical")
                .font(.title)
                .fontWeight(.bold)

            Text("Secure storage for your family's health records")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Username input section
            VStack(spacing: 16) {
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isUsernameFocused)
                    .submitLabel(.continue)
                    .onSubmit { submitUsername() }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .accessibilityIdentifier("usernameField")

                // Validation hint
                if let error = viewModel.usernameValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityIdentifier("usernameValidationHint")
                }

                // Continue button (for new users)
                Button(action: submitUsername) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.isUsernameValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!viewModel.isUsernameValid || viewModel.isLoading)
                .accessibilityIdentifier("continueButton")

                // Sign in button (for returning users)
                Button("I already have an account") {
                    viewModel.proceedAsReturningUser()
                }
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .disabled(!viewModel.isUsernameValid || viewModel.isLoading)
                .accessibilityIdentifier("signInButton")

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
            isUsernameFocused = true
        }
    }

    private func submitUsername() {
        Task {
            await viewModel.submitUsername()
        }
    }
}

#Preview {
    UsernameEntryView(viewModel: AuthenticationViewModel())
}
