import Combine
import SwiftUI

struct UnlockView: View {
    @Bindable var viewModel: AuthenticationViewModel

    enum UnlockField: Hashable {
        case passphrase
    }

    @FocusState private var focusedField: UnlockField?
    @State private var timerCancellable: AnyCancellable?
    @State private var displayedUsername: String = ""
    @State private var timerTick: Int = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon/branding
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityLabel("Family Medical App icon")

            Text("Family Medical App")
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            // Biometric or passphrase input
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
                                .accessibilityHidden(true)

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

                    Button("Use Passphrase") {
                        viewModel.showBiometricPrompt = false
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("usePassphraseButton")
                } else {
                    // Password entry - NO Form, just plain TextFields like Duolingo
                    VStack(spacing: 12) {
                        // Username display (read-only - OPAQUE uses stored username)
                        HStack {
                            Text(displayedUsername)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .accessibilityIdentifier("usernameField")

                        // Passphrase field
                        Group {
                            if UITestingHelpers.isUITesting {
                                TextField("Passphrase", text: $viewModel.unlockPassword)
                            } else {
                                SecureField("Passphrase", text: $viewModel.unlockPassword)
                                    .textContentType(.password)
                            }
                        }
                        .focused($focusedField, equals: .passphrase)
                        .submitLabel(.done)
                        .onSubmit { submitUnlock() }
                        .disabled(viewModel.isLockedOut)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .accessibilityIdentifier("passphraseField")

                        // Unlock button
                        Button(action: submitUnlock) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(viewModel.unlockPassword.isEmpty || viewModel.isLockedOut ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.unlockPassword.isEmpty || viewModel.isLockedOut || viewModel.isLoading)
                        .accessibilityIdentifier("unlockButton")
                    }
                    .onAppear {
                        displayedUsername = viewModel.storedUsername
                        focusedField = .passphrase
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

                // Lockout message with live countdown
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
        .onAppear {
            startLockoutTimer()
        }
        .onDisappear {
            timerCancellable?.cancel()
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

    private func submitUnlock() {
        Task {
            await viewModel.unlockWithPassword()
        }
    }

    private func startLockoutTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Increment tick to force SwiftUI re-render and update countdown
                timerTick += 1
            }
    }
}

#Preview {
    UnlockView(viewModel: AuthenticationViewModel())
}
