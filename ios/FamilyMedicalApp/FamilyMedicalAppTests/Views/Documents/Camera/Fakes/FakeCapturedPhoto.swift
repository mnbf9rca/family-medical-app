import Foundation
import UniformTypeIdentifiers
@testable import FamilyMedicalApp

struct FakeCapturedPhoto: CapturedPhoto {
    let fileData: Data?
    let uniformType: UTType
}
