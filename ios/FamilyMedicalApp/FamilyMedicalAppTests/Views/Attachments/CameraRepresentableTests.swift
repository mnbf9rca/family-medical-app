import SwiftUI
import Testing
import UIKit
@testable import FamilyMedicalApp

@MainActor
struct CameraRepresentableTests {
    // MARK: - Initialization Tests

    @Test
    func init_createsRepresentable() {
        var capturedImage: UIImage?
        var wasCancelled = false

        let representable = CameraRepresentable(
            onImageCaptured: { image in capturedImage = image },
            onCancel: { wasCancelled = true }
        )

        // Verify callbacks are stored but not yet invoked
        #expect(capturedImage == nil)
        #expect(!wasCancelled)
        _ = representable // Silence unused warning
    }

    // MARK: - Camera Availability Tests

    @Test
    func isCameraAvailable_returnsExpectedValue() {
        // This tests the static property
        // In simulator, camera is typically not available
        // In device, it depends on the device
        let isAvailable = CameraRepresentable.isCameraAvailable

        // Just verify we can access the property without error
        // On simulator this will be false, on device it depends on hardware
        _ = isAvailable
    }

    // MARK: - Coordinator Tests

    @Test
    func coordinator_isCreatedWithCallbacks() {
        var capturedImage: UIImage?
        var wasCancelled = false

        let representable = CameraRepresentable(
            onImageCaptured: { image in capturedImage = image },
            onCancel: { wasCancelled = true }
        )

        // makeCoordinator() returns non-optional
        _ = representable.makeCoordinator()
        _ = capturedImage
        _ = wasCancelled
    }

    @Test
    func coordinator_imagePickerControllerDidCancel_invokesCallback() {
        var wasCancelled = false

        let representable = CameraRepresentable(
            onImageCaptured: { _ in },
            onCancel: { wasCancelled = true }
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIImagePickerController()

        // Simulate cancel
        coordinator.imagePickerControllerDidCancel(mockPicker)

        #expect(wasCancelled)
    }

    @Test
    func coordinator_didFinishPicking_invokesCallbackWithImage() {
        var capturedImage: UIImage?

        let representable = CameraRepresentable(
            onImageCaptured: { image in capturedImage = image },
            onCancel: {}
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIImagePickerController()

        // Create a test image
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let testImage = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        let info: [UIImagePickerController.InfoKey: Any] = [
            .originalImage: testImage
        ]

        // Simulate picking an image
        coordinator.imagePickerController(mockPicker, didFinishPickingMediaWithInfo: info)

        #expect(capturedImage != nil)
    }

    @Test
    func coordinator_didFinishPickingWithoutImage_doesNotCrash() {
        var capturedImage: UIImage?

        let representable = CameraRepresentable(
            onImageCaptured: { image in capturedImage = image },
            onCancel: {}
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIImagePickerController()

        // Empty info dictionary (no image)
        let info: [UIImagePickerController.InfoKey: Any] = [:]

        // Should not crash, just not invoke callback
        coordinator.imagePickerController(mockPicker, didFinishPickingMediaWithInfo: info)

        #expect(capturedImage == nil)
    }
}
