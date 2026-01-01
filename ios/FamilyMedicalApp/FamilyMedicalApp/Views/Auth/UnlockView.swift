import SwiftUI

struct UnlockView: View {
    @Bindable var viewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon/branding
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Family Medical App")
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            // Biometric or password input
            VStack(spacing: 20) {
                if viewModel.showBiometricPrompt {
                    // Biometric button
                    Button(action: {
                        Task {
                            await viewModel.unlockWithBiometric()
                        }
                    }, label: {
                        VStack(spacing: 12) {
                            Image(systemName: viewModel.biometryType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 50))

                            Text("Unlock with \(viewModel.biometryType == .faceID ? "Face ID" : "Touch ID")")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    })
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("biometricButton")

                    Button("Use Password") {
                        viewModel.showBiometricPrompt = false
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("usePasswordButton")
                } else {
                    // Password field
                    VStack(spacing: 16) {
                        Group {
                            if UITestingHelpers.isUITesting {
                                // Use TextField in UI testing mode to avoid autofill issues
                                TextField("Enter password", text: $viewModel.unlockPassword)
                            } else {
                                SecureField("Enter password", text: $viewModel.unlockPassword)
                                    .textContentType(.password)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            Task {
                                await viewModel.unlockWithPassword()
                            }
                        }
                        .disabled(viewModel.isLockedOut)
                        .accessibilityIdentifier("passwordField")

                        Button(action: {
                            Task {
                                await viewModel.unlockWithPassword()
                            }
                        }, label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Unlock")
                                    .fontWeight(.semibold)
                            }
                        })
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.unlockPassword.isEmpty || viewModel.isLockedOut ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(viewModel.unlockPassword.isEmpty || viewModel.isLockedOut || viewModel.isLoading)
                        .accessibilityIdentifier("unlockButton")
                    }

                    // Switch back to biometric if available
                    if viewModel.isBiometricEnabled, !viewModel.showBiometricPrompt {
                        Button("Use \(viewModel.biometryType == .faceID ? "Face ID" : "Touch ID")") {
                            viewModel.showBiometricPrompt = true
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("useBiometricButton")
                    }
                }

                // Failed attempts indicator
                if viewModel.failedAttempts > 0, !viewModel.isLockedOut {
                    Text("\(viewModel.failedAttempts) failed attempt\(viewModel.failedAttempts == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityIdentifier("failedAttemptsLabel")
                }

                // Lockout message
                if viewModel.isLockedOut {
                    Text("Too many failed attempts. Try again in \(formattedLockoutTime)")
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier("lockoutLabel")
                }

                // Error message
                if let errorMessage = viewModel.errorMessage, !viewModel.isLockedOut {
                    Text(errorMessage)
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
        .task {
            await viewModel.attemptBiometricOnAppear()
        }
    }

    private var formattedLockoutTime: String {
        let seconds = viewModel.lockoutTimeRemaining
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    UnlockView(viewModel: AuthenticationViewModel())
}
