import Foundation

extension Data {
    /// Convert Data to byte array for Sodium library operations
    var bytes: [UInt8] {
        Array(self)
    }
}
