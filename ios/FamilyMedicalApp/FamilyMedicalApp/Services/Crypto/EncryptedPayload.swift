import Foundation

/// Container for AES-256-GCM encrypted data
///
/// Structure matches the output of CryptoKit's AES.GCM.SealedBox:
/// - 96-bit (12 bytes) nonce/IV
/// - Variable-length ciphertext
/// - 128-bit (16 bytes) authentication tag
struct EncryptedPayload: Codable, Equatable {
    /// 96-bit (12 bytes) random nonce/IV
    let nonce: Data

    /// Encrypted ciphertext
    let ciphertext: Data

    /// 128-bit (16 bytes) authentication tag
    let tag: Data

    /// Combined format: nonce || ciphertext || tag (for storage/transmission)
    var combined: Data {
        var result = Data()
        result.append(nonce)
        result.append(ciphertext)
        result.append(tag)
        return result
    }

    /// Initialize from individual components
    ///
    /// - Parameters:
    ///   - nonce: 12-byte nonce
    ///   - ciphertext: Encrypted payload bytes
    ///   - tag: 16-byte authentication tag
    /// - Throws: CryptoError.invalidPayload if nonce or tag have invalid length
    init(nonce: Data, ciphertext: Data, tag: Data) throws {
        guard nonce.count == 12 else {
            throw CryptoError.invalidPayload("Nonce must be 12 bytes (got \(nonce.count))")
        }

        guard tag.count == 16 else {
            throw CryptoError.invalidPayload("Authentication tag must be 16 bytes (got \(tag.count))")
        }

        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }

    /// Initialize from combined format (nonce || ciphertext || tag)
    ///
    /// - Parameter combined: Combined data with minimum 28 bytes (12 + 0 + 16)
    /// - Throws: CryptoError.invalidPayload if data is too short
    init(combined: Data) throws {
        guard combined.count >= 28 else {
            throw CryptoError.invalidPayload("Combined data too short (min 28 bytes)")
        }

        nonce = combined.prefix(12)
        tag = combined.suffix(16)
        ciphertext = combined.dropFirst(12).dropLast(16)
    }
}
