import SwiftUI

/// Username entry step in the authentication flow
///
/// For new users: continues to PassphraseCreationView
/// For returning users: continues to PassphraseEntryView
struct UsernameEntryView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let isNewUser: Bool
    @FocusState private var isUsernameFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Context-aware header
            Image(systemName: isNewUser ? "person.badge.plus" : "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .accessibilityHidden(true)

            Text(isNewUser ? "Create Your Account" : "Welcome Back")
                .font(.title)
                .fontWeight(.bold)

            Text(isNewUser
                ? "Choose a username for your account"
                : "Enter your username to sign in")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

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

                // Continue button
                Button(action: submitUsername) {
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
                .background(viewModel.isUsernameValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!viewModel.isUsernameValid || viewModel.isLoading)
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

            // Back button
            Button("Back") {
                viewModel.goBack()
            }
            .foregroundColor(.blue)
            .accessibilityIdentifier("backButton")

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

#Preview("New User") {
    UsernameEntryView(viewModel: AuthenticationViewModel(), isNewUser: true)
}

#Preview("Returning User") {
    UsernameEntryView(viewModel: AuthenticationViewModel(), isNewUser: false)
}
