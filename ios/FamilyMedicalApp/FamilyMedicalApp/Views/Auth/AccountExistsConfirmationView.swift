import SwiftUI

/// Confirmation view shown when user tried to register but already has an account
///
/// This is shown after the client:
/// 1. Attempted registration which failed
/// 2. Silently probed login with same credentials
/// 3. Login succeeded (proving user owns this account)
///
/// The user can either:
/// - Continue to log in (using the already-authenticated session)
/// - Cancel and try a different username
struct AccountExistsConfirmationView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let username: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityLabel("Account found icon")

            // Title
            Text("Account Found")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Message
            VStack(spacing: 8) {
                Text("Looks like you already have an account with username \"\(username)\".")
                Text("Would you like to log in instead?")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.confirmExistingAccount()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("confirmLoginButton")

                Button {
                    viewModel.cancelExistingAccountConfirmation()
                } label: {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("cancelButton")
            }
            .padding(.horizontal)

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
                .frame(height: 48)
        }
        .padding()
    }
}

#Preview {
    AccountExistsConfirmationView(
        viewModel: AuthenticationViewModel(),
        username: "testuser"
    )
}
