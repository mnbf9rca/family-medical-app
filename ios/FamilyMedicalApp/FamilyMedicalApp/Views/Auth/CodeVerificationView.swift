import SwiftUI

/// Second step in authentication flow: verification code entry
///
/// Displays 6 input fields for the verification code sent to the user's email.
/// On success, progresses to either PassphraseCreationView (new user) or
/// PassphraseEntryView (returning user).
struct CodeVerificationView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let email: String

    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("Check your email")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("We sent a verification code to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .accessibilityIdentifier("emailDisplay")
            }

            Spacer()

            // Code input section
            VStack(spacing: 20) {
                // 6-digit code field
                TextField("Enter 6-digit code", text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .focused($isCodeFocused)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .accessibilityIdentifier("codeField")
                    .onChange(of: viewModel.verificationCode) { _, newValue in
                        // Limit to 6 digits
                        let filtered = newValue.filter(\.isNumber)
                        if filtered.count > 6 {
                            viewModel.verificationCode = String(filtered.prefix(6))
                        } else if filtered != newValue {
                            viewModel.verificationCode = filtered
                        }
                    }

                // Verify button
                Button(action: verifyCode) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Verify")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.verificationCode.count == 6 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.verificationCode.count != 6 || viewModel.isLoading)
                .accessibilityIdentifier("verifyButton")

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("errorLabel")
                }

                // Resend code option
                HStack {
                    Text("Didn't receive the code?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Resend") {
                        Task {
                            await viewModel.resendVerificationCode()
                        }
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("resendButton")
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
            isCodeFocused = true
        }
    }

    private func verifyCode() {
        Task {
            await viewModel.submitVerificationCode()
        }
    }
}

#Preview {
    CodeVerificationView(
        viewModel: AuthenticationViewModel(),
        email: "test@example.com"
    )
}
