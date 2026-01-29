import SwiftUI

struct AuthenticationCoordinatorView: View {
    @Bindable var viewModel: AuthenticationViewModel
    @Environment(\.scenePhase)
    private var scenePhase

    init(viewModel: AuthenticationViewModel = AuthenticationViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.flowState {
            case .usernameEntry:
                UsernameEntryView(viewModel: viewModel)

            case let .passphraseCreation(username):
                PassphraseCreationView(viewModel: viewModel, username: username)

            case let .passphraseConfirmation(username, passphrase):
                PassphraseConfirmView(viewModel: viewModel, username: username, passphrase: passphrase)

            case let .passphraseEntry(username, _):
                PassphraseEntryView(viewModel: viewModel, username: username)

            case let .biometricSetup(username, passphrase, _):
                BiometricSetupView(viewModel: viewModel, username: username, passphrase: passphrase)

            case .unlock:
                UnlockView(viewModel: viewModel)

            case .authenticated:
                MainAppView(viewModel: viewModel)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            // Record background time for lock timeout
            if viewModel.isAuthenticated {
                viewModel.lockStateService.recordBackgroundTime()
            }

        case .active:
            // Check if should lock based on timeout
            if viewModel.isAuthenticated, viewModel.lockStateService.shouldLockOnForeground() {
                viewModel.lock()
            }

        @unknown default:
            break
        }
    }
}

/// Main app view (placeholder - will be replaced with actual content)
struct MainAppView: View {
    @Bindable var viewModel: AuthenticationViewModel

    var body: some View {
        NavigationStack {
            ContentView()
                .navigationTitle("Medical Records")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                viewModel.lock()
                            }, label: {
                                Label("Lock App", systemImage: "lock")
                            })

                            Button(
                                role: .destructive,
                                action: {
                                    Task {
                                        await viewModel.logout()
                                    }
                                },
                                label: {
                                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            )
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
        }
    }
}

#Preview {
    AuthenticationCoordinatorView()
}
