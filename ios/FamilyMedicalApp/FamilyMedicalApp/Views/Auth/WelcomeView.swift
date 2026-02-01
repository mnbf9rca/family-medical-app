import SwiftUI

/// Welcome screen - first step for users without an existing local account
///
/// Presents two clear options:
/// - Create a new account (OPAQUE registration flow)
/// - Sign in to existing account (OPAQUE login flow)
struct WelcomeView: View {
    @Bindable var viewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App branding
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                .accessibilityLabel("Family Medical App icon")

            Text("Family Medical")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Secure storage for your family's health records")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                Button {
                    viewModel.selectCreateAccount()
                } label: {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .accessibilityIdentifier("createAccountButton")

                Button {
                    viewModel.selectSignIn()
                } label: {
                    Text("I Already Have an Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .accessibilityIdentifier("signInButton")

                // Demo mode separator
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)

                // Demo mode button
                Button {
                    viewModel.selectDemo()
                } label: {
                    Label("Try Demo", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("tryDemoButton")
            }
            .padding(.horizontal)

            Spacer()
                .frame(height: 48)
        }
        .padding()
    }
}

#Preview {
    WelcomeView(viewModel: AuthenticationViewModel())
}
