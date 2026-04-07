import SwiftUI

/// View modifier that shows a security warning before exporting/sharing attachments
///
/// Per security requirements: Users must be warned that exported files are decrypted
/// and anyone they share with can view the contents.
struct ExportWarningModifier: ViewModifier {
    /// Whether to show the warning dialog
    @Binding var isPresented: Bool

    /// Called when user confirms export
    let onConfirm: () -> Void

    /// Called when user cancels
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Export Attachment", isPresented: $isPresented) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Button("Export") {
                    onConfirm()
                }
            } message: {
                Text(
                    """
                    This will share the decrypted file. Anyone you share it with can view and copy its contents.

                    The exported file is NOT encrypted.
                    """
                )
            }
    }
}

// MARK: - View Extension

extension View {
    /// Shows a security warning dialog before exporting an attachment
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control dialog visibility
    ///   - onConfirm: Called when user confirms export
    ///   - onCancel: Called when user cancels (optional)
    func exportWarning(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(ExportWarningModifier(
            isPresented: isPresented,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var showWarning = false

    VStack {
        Button("Show Warning") {
            showWarning = true
        }
    }
    .exportWarning(isPresented: $showWarning) {
        showWarning = false
    } onCancel: {
        showWarning = false
    }
}
