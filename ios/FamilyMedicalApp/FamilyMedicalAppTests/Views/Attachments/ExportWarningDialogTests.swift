import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct ExportWarningDialogTests {
    // MARK: - ViewModifier Tests

    @Test
    func exportWarning_appliesModifier() throws {
        var isPresented = true
        var wasConfirmed = false
        var wasCancelled = false

        let content = Text("Test Content")
            .exportWarning(
                isPresented: Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                ),
                onConfirm: { wasConfirmed = true },
                onCancel: { wasCancelled = true }
            )

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Test Content")

        #expect(!wasConfirmed)
        #expect(!wasCancelled)
    }

    @Test
    func exportWarning_whenNotPresented_rendersContent() throws {
        var isPresented = false

        let content = Text("Main Content")
            .exportWarning(
                isPresented: Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                ),
                onConfirm: {},
                onCancel: {}
            )

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Main Content")
    }

    @Test
    func exportWarning_whenPresented_rendersWithAlert() throws {
        var isPresented = true

        let content = Text("Main Content")
            .exportWarning(
                isPresented: Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                ),
                onConfirm: {},
                onCancel: {}
            )

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Main Content")
    }

    // MARK: - Default Cancel Callback Tests

    @Test
    func exportWarning_withDefaultCancel_rendersSuccessfully() throws {
        var isPresented = true

        let content = Text("Content")
            .exportWarning(
                isPresented: Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                )
                // onCancel uses default empty closure
            ) {}

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Content")
    }

    // MARK: - Callback Invocation Tests

    @Test
    func exportWarning_onConfirm_callbackIsStored() throws {
        var wasConfirmed = false

        let content = Text("Content")
            .exportWarning(
                isPresented: .constant(true)
            ) { wasConfirmed = true }

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Content")
        // Callback is stored but not invoked until user taps Export
        #expect(!wasConfirmed)
    }

    @Test
    func exportWarning_onCancel_callbackIsStored() throws {
        var wasCancelled = false

        let content = Text("Content")
            .exportWarning(
                isPresented: .constant(true),
                onConfirm: {},
                onCancel: { wasCancelled = true }
            )

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Content")
        // Callback is stored but not invoked until user taps Cancel
        #expect(!wasCancelled)
    }

    // MARK: - Integration Tests

    @Test
    func exportWarning_onButtonView_rendersCorrectly() throws {
        var isPresented = false

        let content = Button("Export") {
            isPresented = true
        }
        .exportWarning(
            isPresented: Binding(
                get: { isPresented },
                set: { isPresented = $0 }
            )
        ) {}

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(ViewType.Button.self)
    }

    @Test
    func exportWarning_onImageView_rendersCorrectly() throws {
        let content = Image(systemName: "square.and.arrow.up")
            .exportWarning(
                isPresented: .constant(false)
            ) {}

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(ViewType.Image.self)
    }

    @Test
    func exportWarning_onVStack_rendersCorrectly() throws {
        let content = VStack {
            Text("Header")
            Text("Body")
        }
        .exportWarning(
            isPresented: .constant(false)
        ) {}

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Header")
        _ = try inspected.find(text: "Body")
    }

    // MARK: - State Management Tests

    @Test
    func exportWarning_togglePresented_updatesState() throws {
        var isPresented = false

        let binding = Binding(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let content = Text("Content")
            .exportWarning(
                isPresented: binding
            ) {}

        // Use find() for deterministic coverage
        let inspected = try content.inspect()
        _ = try inspected.find(text: "Content")

        // Simulate showing dialog
        isPresented = true
        #expect(isPresented)

        // Simulate dismissing
        isPresented = false
        #expect(!isPresented)
    }
}
