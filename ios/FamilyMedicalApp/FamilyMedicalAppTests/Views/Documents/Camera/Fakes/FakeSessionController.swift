import AVFoundation
import CoreGraphics
import Foundation
@testable import FamilyMedicalApp

final class FakeSessionController: SessionController, @unchecked Sendable {
    private(set) var isRunning: Bool = false
    private(set) var startCalls: Int = 0
    private(set) var stopCalls: Int = 0
    private(set) var swapCameraPositionCalls: Int = 0
    private(set) var setFocusPointCalls: [CGPoint] = []
    private(set) var qualityPrioritizationCalls: [AVCapturePhotoOutput.QualityPrioritization] = []

    func start() {
        startCalls += 1
        isRunning = true
    }

    func stop() {
        stopCalls += 1
        isRunning = false
    }

    func swapCameraPosition() {
        swapCameraPositionCalls += 1
    }

    func setFocusPoint(_ point: CGPoint) {
        setFocusPointCalls.append(point)
    }

    func setQualityPrioritization(_ prioritization: AVCapturePhotoOutput.QualityPrioritization) {
        qualityPrioritizationCalls.append(prioritization)
    }
}
