import CryptoKit
import Foundation

// PROOF OF CONCEPT: Symmetric Key Wrapping Pattern
// This demonstrates how to use AES Key Wrapping (RFC 3394 / NIST SP 800-38F)
// to share encrypted medical records with multiple family members.

// PATTERN: Each medical record is encrypted with a Data Encryption Key (DEK).
// The DEK is then "wrapped" (encrypted) with each authorized user's primary key.
// This allows multiple users to decrypt the same record using their own keys.

// Namespace enum for symmetric key wrapping example; not intended to be instantiated.
enum SymmetricKeyWrappingExample {
    // STEP 1: User derives their primary key from password
    static func derivePrimaryKey(from password: String, salt: Data) -> SymmetricKey {
        // Using PBKDF2-HMAC-SHA256 with 100k iterations (AGENTS.md requirement)
        let passwordData = password.data(using: .utf8)!

        // Note: CryptoKit doesn't have built-in PBKDF2, so in production you'd use:
        // - CommonCrypto's CCKeyDerivationPBKDF
        // - Or use Argon2id via a vetted third-party wrapper

        // For this PoC, we'll generate a key directly
        // In production: primaryKey = PBKDF2(password, salt, iterations: 100_000)
        return SymmetricKey(size: .bits256)
    }

    // STEP 2: Generate a random Data Encryption Key (DEK) for a medical record
    static func generateDataEncryptionKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // STEP 3: Encrypt medical record data with the DEK
    static func encryptMedicalRecord(data: Data, using dek: SymmetricKey) throws -> Data {
        // Using AES-256-GCM per AGENTS.md
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: dek, nonce: nonce)

        // Combine nonce + ciphertext + tag for storage
        return sealedBox.combined!
    }

    // STEP 4: Wrap the DEK with each user's primary key (AES Key Wrap)
    static func wrapDataKey(_ dek: SymmetricKey, with primaryKey: SymmetricKey) throws -> Data {
        // CryptoKit's AES.KeyWrap implements RFC 3394
        let wrappedKey = try AES.KeyWrap.wrap(dek, using: primaryKey)
        return wrappedKey
    }

    // STEP 5: Store the encrypted record + wrapped keys for each user
    struct StoredMedicalRecord {
        let recordId: UUID
        let encryptedData: Data // Encrypted with DEK
        let wrappedKeys: [String: Data] // userId -> wrapped DEK

        // In production, this would be stored in Core Data with field-level encryption
    }

    // EXAMPLE USAGE: Adult A shares Child 1's vaccine record with Adult B
    static func demonstrateSharing() throws {
        print("=== Symmetric Key Wrapping Demo ===\n")

        // Adult A and Adult B each have their own primary keys
        let adultA_primaryKey = derivePrimaryKey(from: "AdultA_password", salt: Data())
        let adultB_primaryKey = derivePrimaryKey(from: "AdultB_password", salt: Data())

        // Adult A creates a vaccine record for Child 1
        let vaccineData = "Child 1: COVID-19 vaccine, Pfizer, 2025-01-15".data(using: .utf8)!

        // Generate DEK for this specific record
        let dek = generateDataEncryptionKey()

        // Encrypt the record with the DEK
        let encryptedRecord = try encryptMedicalRecord(data: vaccineData, using: dek)
        print("✓ Encrypted vaccine record: \(encryptedRecord.count) bytes")

        // Wrap the DEK for Adult A (owner)
        let wrappedKey_AdultA = try wrapDataKey(dek, with: adultA_primaryKey)
        print("✓ Wrapped DEK for Adult A: \(wrappedKey_AdultA.count) bytes")

        // Wrap the DEK for Adult B (shared access)
        let wrappedKey_AdultB = try wrapDataKey(dek, with: adultB_primaryKey)
        print("✓ Wrapped DEK for Adult B: \(wrappedKey_AdultB.count) bytes")

        // Store the record with both wrapped keys
        let storedRecord = StoredMedicalRecord(
            recordId: UUID(),
            encryptedData: encryptedRecord,
            wrappedKeys: [
                "adultA": wrappedKey_AdultA,
                "adultB": wrappedKey_AdultB
            ]
        )

        print("\n--- Adult B Decrypts the Record ---")

        // Adult B unwraps the DEK using their primary key
        let unwrappedDEK = try AES.KeyWrap.unwrap(wrappedKey_AdultB, using: adultB_primaryKey)
        print("✓ Adult B unwrapped DEK")

        // Adult B decrypts the record
        let sealedBox = try AES.GCM.SealedBox(combined: storedRecord.encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: unwrappedDEK)
        let decryptedText = String(data: decryptedData, encoding: .utf8)!
        print("✓ Decrypted: \(decryptedText)")

        print("\n--- Storage Overhead Analysis ---")
        print("Original data: \(vaccineData.count) bytes")
        print("Encrypted data: \(encryptedRecord.count) bytes")
        print("Wrapped key per user: \(wrappedKey_AdultA.count) bytes")
        print("Total for 2 users: \(encryptedRecord.count + wrappedKey_AdultA.count + wrappedKey_AdultB.count) bytes")
    }

    // PROS:
    // ✓ Simple pattern, well-understood
    // ✓ CryptoKit has native support (AES.KeyWrap)
    // ✓ Efficient: small wrapped keys (~40 bytes each)
    // ✓ Easy to add new users (just wrap DEK with their primary key)

    // CONS:
    // ✗ Storage overhead: N wrapped keys per record (N = # authorized users)
    // ✗ Key rotation requires re-wrapping for all users
    // ✗ No forward secrecy (if primary key compromised, all records compromised)

    // SUITABILITY FOR MEDICAL RECORDS:
    // ✓ GOOD - Medical records are relatively static (not real-time messaging)
    // ✓ GOOD - Small number of users per record (typically 2-3 adults)
    // ✓ GOOD - Offline-first compatible
    // ✗ CONSIDERATION - Access revocation requires re-encryption with new DEK
}

// Run the demo
try? SymmetricKeyWrappingExample.demonstrateSharing()
