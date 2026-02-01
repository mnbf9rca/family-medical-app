import SwiftUI

/// Loading view shown while demo mode is being set up
struct DemoSetupView: View {
    @Bindable var viewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Setting Up Demo")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Creating sample data...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ProgressView()
                .scaleEffect(1.5)

            Spacer()

            // Error display
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    Button("Go Back") {
                        viewModel.flowState = .welcome
                        viewModel.errorMessage = nil
                    }
                    .font(.footnote)
                }
                .padding()
            }
        }
        .padding()
        .task {
            await viewModel.enterDemoMode()
        }
    }
}

#Preview {
    DemoSetupView(viewModel: AuthenticationViewModel())
}
