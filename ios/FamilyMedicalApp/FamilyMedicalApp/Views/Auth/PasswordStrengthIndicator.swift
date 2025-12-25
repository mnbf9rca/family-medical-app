import SwiftUI

struct PasswordStrengthIndicator: View {
    let strength: PasswordStrength

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1 ... 4, id: \.self) { index in
                    Rectangle()
                        .fill(index <= strength.rawValue ? strengthColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }

            Text(strength.displayName)
                .font(.caption)
                .foregroundColor(strengthColor)
        }
    }

    private var strengthColor: Color {
        switch strength {
        case .weak:
            .red
        case .fair:
            .orange
        case .good:
            .yellow
        case .strong:
            .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PasswordStrengthIndicator(strength: .weak)
        PasswordStrengthIndicator(strength: .fair)
        PasswordStrengthIndicator(strength: .good)
        PasswordStrengthIndicator(strength: .strong)
    }
    .padding()
}
