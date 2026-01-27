import SwiftUI

/// First step in the authentication flow: email entry
///
/// The user enters their email address, which triggers a verification code
/// to be sent. The flow continues to CodeVerificationView on success.
struct EmailEntryView: View {
    @Bindable var viewModel: AuthenticationViewModel
    @FocusState private var isEmailFocused: Bool

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

            // Email input section
            VStack(spacing: 16) {
                TextField("Email address", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.continue)
                    .onSubmit { submitEmail() }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .accessibilityIdentifier("emailField")

                // Continue button
                Button(action: submitEmail) {
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
                .background(viewModel.isEmailValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!viewModel.isEmailValid || viewModel.isLoading)
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
            isEmailFocused = true
        }
    }

    private func submitEmail() {
        Task {
            await viewModel.submitEmail()
        }
    }
}

#Preview {
    EmailEntryView(viewModel: AuthenticationViewModel())
}
