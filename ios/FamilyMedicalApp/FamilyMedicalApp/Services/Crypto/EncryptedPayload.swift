import Foundation

/// Container for AES-256-GCM encrypted data
///
/// Structure matches the output of CryptoKit's AES.GCM.SealedBox:
/// - 96-bit (12 bytes) nonce/IV
/// - Variable-length ciphertext
/// - 128-bit (16 bytes) authentication tag
struct EncryptedPayload: Codable, Equatable {
    // AES-GCM standard sizes
    static let nonceLength = 12 // 96-bit nonce
    static let tagLength = 16 // 128-bit authentication tag
    static let minimumCombinedLength = nonceLength + tagLength // 28 bytes minimum (empty ciphertext)

    /// 96-bit (12 bytes) random nonce/IV
    let nonce: Data

    /// Encrypted ciphertext
    let ciphertext: Data

    /// 128-bit (16 bytes) authentication tag
    let tag: Data

    /// Combined format: nonce || ciphertext || tag (for storage/transmission)
    var combined: Data {
        var result = Data(capacity: nonce.count + ciphertext.count + tag.count)
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
        guard nonce.count == Self.nonceLength else {
            throw CryptoError.invalidPayload("Nonce must be \(Self.nonceLength) bytes (got \(nonce.count))")
        }

        guard tag.count == Self.tagLength else {
            throw CryptoError.invalidPayload("Authentication tag must be \(Self.tagLength) bytes (got \(tag.count))")
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
        guard combined.count >= Self.minimumCombinedLength else {
            throw CryptoError.invalidPayload("Combined data too short (min \(Self.minimumCombinedLength) bytes)")
        }

        nonce = combined.prefix(Self.nonceLength)
        tag = combined.suffix(Self.tagLength)
        ciphertext = combined.dropFirst(Self.nonceLength).dropLast(Self.tagLength)
    }
}
