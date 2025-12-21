import CryptoKit
import Foundation

// PROOF OF CONCEPT: Public-Key Encryption for Sharing
// This demonstrates how to share medical records using Curve25519 public-key encryption.
// This pattern works over INSECURE channels (no need for iCloud Family or secure transport).

// PATTERN: Each user has a Curve25519 keypair (private/public).
// When Adult A shares a record with Adult B:
// 1. Adult A performs ECDH key agreement using A's private key + B's public key
// 2. Derive a shared secret using HKDF
// 3. Wrap the DEK with the shared secret
// This allows secure sharing without requiring a secure channel for key exchange.

// Namespace enum for public-key sharing example; not intended to be instantiated.
enum PublicKeySharingExample {
    // User's identity: keypair for key exchange
    struct UserIdentity {
        let userId: String
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        let publicKey: Curve25519.KeyAgreement.PublicKey

        init(userId: String) {
            self.userId = userId
            privateKey = Curve25519.KeyAgreement.PrivateKey()
            publicKey = privateKey.publicKey
        }

        // Public key can be shared over insecure channels
        func exportPublicKey() -> Data {
            publicKey.rawRepresentation
        }

        static func importPublicKey(from data: Data) throws -> Curve25519.KeyAgreement.PublicKey {
            try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        }
    }

    // STEP 1: Perform ECDH key agreement to derive shared secret
    static func deriveSharedSecret(
        myPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        theirPublicKey: Curve25519.KeyAgreement.PublicKey,
        context: String // e.g., "medical_record_sharing"
    ) throws -> SymmetricKey {
        // Perform X25519 key agreement
        let sharedSecret = try myPrivateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)

        // Derive symmetric key using HKDF (best practice: don't use raw shared secret)
        let contextData = context.data(using: .utf8)!
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(), // In production, use a per-record salt
            sharedInfo: contextData,
            outputByteCount: 32 // 256 bits
        )

        return symmetricKey
    }

    // STEP 2: Wrap DEK using the derived shared secret
    static func wrapDEK(
        _ dek: SymmetricKey,
        forRecipient recipientPublicKey: Curve25519.KeyAgreement.PublicKey,
        senderPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        recordId: UUID
    ) throws -> Data {
        // Derive shared secret between sender and recipient
        let sharedSecret = try deriveSharedSecret(
            myPrivateKey: senderPrivateKey,
            theirPublicKey: recipientPublicKey,
            context: "share_record_\(recordId.uuidString)"
        )

        // Wrap DEK with the shared secret
        return try AES.KeyWrap.wrap(dek, using: sharedSecret)
    }

    // STEP 3: Unwrap DEK using recipient's private key
    static func unwrapDEK(
        wrappedDEK: Data,
        senderPublicKey: Curve25519.KeyAgreement.PublicKey,
        recipientPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        recordId: UUID
    ) throws -> SymmetricKey {
        // Re-derive the same shared secret
        let sharedSecret = try deriveSharedSecret(
            myPrivateKey: recipientPrivateKey,
            theirPublicKey: senderPublicKey,
            context: "share_record_\(recordId.uuidString)"
        )

        // Unwrap DEK
        return try AES.KeyWrap.unwrap(wrappedDEK, using: sharedSecret)
    }

    // Storage structure for a shared medical record
    struct SharedMedicalRecord {
        let recordId: UUID
        let encryptedData: Data // Encrypted with DEK using AES-GCM
        let ownerPublicKey: Data // Curve25519 public key of record creator

        // Wrapped DEK for each authorized user
        // Key: recipient's userId
        // Value: DEK wrapped with ECDH-derived shared secret
        let wrappedDEKs: [String: Data]
    }

    // EXAMPLE USAGE: Sharing over insecure channel
    static func demonstratePublicKeySharing() throws {
        print("=== Public-Key Sharing Demo (Insecure Channel) ===\n")

        // Adult A and Adult B create their keypairs
        let adultA = UserIdentity(userId: "adultA")
        let adultB = UserIdentity(userId: "adultB")

        // PUBLIC KEY EXCHANGE (can happen over insecure channel!)
        // Adult A sends their public key to Adult B (e.g., via QR code, email, server)
        let adultA_publicKeyData = adultA.exportPublicKey()
        print("✓ Adult A shares public key: \(adultA_publicKeyData.base64EncodedString().prefix(20))...")

        // Adult B sends their public key to Adult A
        let adultB_publicKeyData = adultB.exportPublicKey()
        print("✓ Adult B shares public key: \(adultB_publicKeyData.base64EncodedString().prefix(20))...\n")

        // --- Adult A creates a medical record for Child 1 ---
        let recordId = UUID()
        let medicalData = "Child 1: MMR vaccine, 2025-02-10, Dr. Smith".data(using: .utf8)!

        // Generate DEK for this record
        let dek = SymmetricKey(size: .bits256)

        // Encrypt the medical data with DEK
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(medicalData, using: dek, nonce: nonce)
        let encryptedData = sealedBox.combined!
        print("✓ Adult A encrypted medical record: \(encryptedData.count) bytes")

        // Wrap DEK for Adult A (self)
        let wrappedDEK_forA = try wrapDEK(
            dek,
            forRecipient: adultA.publicKey,
            senderPrivateKey: adultA.privateKey,
            recordId: recordId
        )
        print("✓ Wrapped DEK for Adult A (owner): \(wrappedDEK_forA.count) bytes")

        // Wrap DEK for Adult B (sharing)
        // Adult A uses Adult B's public key (received earlier)
        let adultB_publicKey = try UserIdentity.importPublicKey(from: adultB_publicKeyData)
        let wrappedDEK_forB = try wrapDEK(
            dek,
            forRecipient: adultB_publicKey,
            senderPrivateKey: adultA.privateKey,
            recordId: recordId
        )
        print("✓ Wrapped DEK for Adult B (shared): \(wrappedDEK_forB.count) bytes")

        // Store the record
        let sharedRecord = SharedMedicalRecord(
            recordId: recordId,
            encryptedData: encryptedData,
            ownerPublicKey: adultA_publicKeyData,
            wrappedDEKs: [
                adultA.userId: wrappedDEK_forA,
                adultB.userId: wrappedDEK_forB
            ]
        )

        print("\n--- Record Stored (can sync via insecure server) ---")
        print("Record ID: \(recordId)")
        print("Encrypted data: \(sharedRecord.encryptedData.count) bytes")
        print("Owner: Adult A")
        print("Authorized users: Adult A, Adult B\n")

        // --- Adult B retrieves and decrypts the record ---
        print("--- Adult B Decrypts the Record ---")

        // Adult B imports Adult A's public key (from record metadata)
        let adultA_publicKey = try UserIdentity.importPublicKey(from: sharedRecord.ownerPublicKey)

        // Adult B unwraps the DEK using their private key + Adult A's public key
        let unwrappedDEK = try unwrapDEK(
            wrappedDEK: sharedRecord.wrappedDEKs[adultB.userId]!,
            senderPublicKey: adultA_publicKey,
            recipientPrivateKey: adultB.privateKey,
            recordId: recordId
        )
        print("✓ Adult B unwrapped DEK")

        // Adult B decrypts the medical data
        let decryptedBox = try AES.GCM.SealedBox(combined: sharedRecord.encryptedData)
        let decryptedData = try AES.GCM.open(decryptedBox, using: unwrappedDEK)
        let decryptedText = String(data: decryptedData, encoding: .utf8)!
        print("✓ Decrypted: \(decryptedText)\n")

        // --- Demonstrate adding a third user (Adult C) ---
        print("--- Adult A Grants Access to Adult C ---")
        let adultC = UserIdentity(userId: "adultC")

        // Adult C shares their public key over insecure channel
        let adultC_publicKeyData = adultC.exportPublicKey()
        print("✓ Adult C shares public key")

        // Adult A first needs to decrypt the record to get the DEK
        let unwrappedDEK_A = try unwrapDEK(
            wrappedDEK: sharedRecord.wrappedDEKs[adultA.userId]!,
            senderPublicKey: adultA.publicKey,
            recipientPrivateKey: adultA.privateKey,
            recordId: recordId
        )

        // Adult A wraps DEK for Adult C
        let adultC_publicKey = try UserIdentity.importPublicKey(from: adultC_publicKeyData)
        let wrappedDEK_forC = try wrapDEK(
            unwrappedDEK_A,
            forRecipient: adultC_publicKey,
            senderPrivateKey: adultA.privateKey,
            recordId: recordId
        )
        print("✓ Adult A wrapped DEK for Adult C: \(wrappedDEK_forC.count) bytes")
        print("✓ Adult C now has access (wrappedDEKs updated)")
    }

    // PROS:
    // ✓ Works over insecure channels (no iCloud Family needed)
    // ✓ Public keys can be exchanged via QR codes, email, server, etc.
    // ✓ CryptoKit native support (Curve25519)
    // ✓ Perfect forward secrecy possible (if keys rotated)
    // ✓ Each recipient gets a unique wrapped key (can revoke individually)

    // CONS:
    // ✗ More complex than pure symmetric wrapping
    // ✗ Requires public key distribution mechanism
    // ✗ Storage overhead: N wrapped keys + N public keys
    // ✗ Access revocation still requires re-encryption

    // SUITABILITY FOR FAMILY MEDICAL APP:
    // ✓ EXCELLENT - No assumptions about iCloud Family
    // ✓ EXCELLENT - QR code key exchange at family gathering
    // ✓ GOOD - Server can store public keys (they're public!)
    // ✓ GOOD - Offline-first compatible
    // ⚠ CONSIDERATION - Need UX for public key verification
}

// Run the demo
try? PublicKeySharingExample.demonstratePublicKeySharing()
