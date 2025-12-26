import SwiftUI

struct PasswordSetupView: View {
    @Bindable var viewModel: AuthenticationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Secure Your Medical Records")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Create a strong password to protect your family's health data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Username field (required for iOS Password AutoFill)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)

                    TextField("Choose a username", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Password fields
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)

                        SecureField("Enter password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .autocorrectionDisabled()

                        if !viewModel.password.isEmpty {
                            PasswordStrengthIndicator(strength: viewModel.passwordStrength)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)

                        SecureField("Confirm password", text: $viewModel.confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .autocorrectionDisabled()
                    }

                    // Validation errors (only shown after user attempts setup)
                    if !viewModel.displayedValidationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.displayedValidationErrors, id: \.self) { error in
                                Label(error.errorDescription ?? "", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Biometric toggle
                if BiometricService().isBiometricAvailable {
                    Toggle(isOn: $viewModel.enableBiometric) {
                        HStack {
                            Image(systemName: BiometricService().biometryType == .faceID ? "faceid" : "touchid")
                            Text("Enable \(BiometricService().biometryType == .faceID ? "Face ID" : "Touch ID")")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                // Continue button
                Button(action: {
                    Task {
                        await viewModel.setUp()
                    }
                }, label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                })
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!canContinue || viewModel.isLoading)

                Spacer()
            }
            .padding()
        }
    }

    private var canContinue: Bool {
        !viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty &&
            !viewModel.password.isEmpty &&
            !viewModel.confirmPassword.isEmpty &&
            viewModel.password == viewModel.confirmPassword &&
            viewModel.passwordValidationErrors.isEmpty
    }
}

#Preview {
    PasswordSetupView(viewModel: AuthenticationViewModel())
}
