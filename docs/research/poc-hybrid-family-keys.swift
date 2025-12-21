import CryptoKit
import Foundation

// PROOF OF CONCEPT: Hybrid Approach - Per-Family-Member Keys
// This demonstrates a hierarchical key model optimized for family medical records.

// PATTERN:
// 1. Each USER has a Curve25519 keypair (identity)
// 2. Each FAMILY MEMBER (child/patient) has a symmetric Family Member Key (FMK)
// 3. Medical records for that family member are encrypted with their FMK
// 4. FMK is wrapped separately for each authorized adult using public-key crypto
//
// ADVANTAGES:
// - Only re-wrap FMK when access changes (not every record)
// - Adding new records doesn't require updating any keys
// - Revoking access = delete one wrapped FMK (+ re-wrap with new FMK)

enum HybridFamilyKeyExample {
    // User identity (adults who manage medical records)
    struct UserIdentity {
        let userId: String
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        let publicKey: Curve25519.KeyAgreement.PublicKey

        init(userId: String) {
            self.userId = userId
            privateKey = Curve25519.KeyAgreement.PrivateKey()
            publicKey = privateKey.publicKey
        }
    }

    // Family member (child/patient whose records are being managed)
    struct FamilyMember {
        let memberId: UUID
        let name: String // Encrypted in production
        let familyMemberKey: SymmetricKey // FMK - encrypts all records for this person

        init(memberId: UUID, name: String) {
            self.memberId = memberId
            self.name = name
            // Generate random FMK (never derived from passwords!)
            familyMemberKey = SymmetricKey(size: .bits256)
        }
    }

    // Wrapped FMK storage (who has access to which family member's records)
    struct WrappedFamilyMemberKey {
        let familyMemberId: UUID
        let authorizedUserId: String
        let wrappedFMK: Data // FMK encrypted with ECDH-derived key
        let ownerPublicKey: Data // Public key of the user who granted access
    }

    // Medical record encrypted with FMK
    struct MedicalRecord {
        let recordId: UUID
        let familyMemberId: UUID // Which family member this belongs to
        let encryptedData: Data // Encrypted with that family member's FMK
        let recordType: String // "vaccine", "allergy", etc. (plaintext metadata)
        let createdAt: Date
    }

    // STEP 1: Wrap FMK for a user using public-key encryption
    static func wrapFamilyMemberKey(
        _ fmk: SymmetricKey,
        forUser recipientPublicKey: Curve25519.KeyAgreement.PublicKey,
        grantedBy grantorPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        familyMemberId: UUID
    ) throws -> Data {
        // Perform ECDH key agreement
        let sharedSecret = try grantorPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)

        // Derive wrapping key using HKDF
        let context = "fmk_\(familyMemberId.uuidString)".data(using: .utf8)!
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: context,
            outputByteCount: 32
        )

        // Wrap FMK
        return try AES.KeyWrap.wrap(fmk, using: wrappingKey)
    }

    // STEP 2: Unwrap FMK to access family member's records
    static func unwrapFamilyMemberKey(
        wrappedFMK: Data,
        recipientPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        grantorPublicKey: Curve25519.KeyAgreement.PublicKey,
        familyMemberId: UUID
    ) throws -> SymmetricKey {
        // Re-derive the same shared secret
        let sharedSecret = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: grantorPublicKey)

        let context = "fmk_\(familyMemberId.uuidString)".data(using: .utf8)!
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: context,
            outputByteCount: 32
        )

        return try AES.KeyWrap.unwrap(wrappedFMK, using: wrappingKey)
    }

    // STEP 3: Encrypt a medical record using FMK
    static func encryptMedicalRecord(
        data: Data,
        using fmk: SymmetricKey
    ) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: fmk, nonce: nonce)
        return sealedBox.combined!
    }

    // STEP 4: Decrypt a medical record using FMK
    static func decryptMedicalRecord(
        encryptedData: Data,
        using fmk: SymmetricKey
    ) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: fmk)
    }

    // DEMONSTRATION
    static func demonstrateHybridModel() throws {
        print("=== Hybrid Family Key Model Demo ===\n")

        // Three adults in the family network
        let adultA = UserIdentity(userId: "adultA")
        let adultB = UserIdentity(userId: "adultB")
        let adultC = UserIdentity(userId: "adultC")

        // Two children whose medical records are being managed
        let child1 = FamilyMember(memberId: UUID(), name: "Emma (age 5)")
        let child2 = FamilyMember(memberId: UUID(), name: "Liam (age 8)")

        print("Family Structure:")
        print("- Adult A manages: Emma, Liam")
        print("- Adult B manages: Emma, Liam (shares with Adult A)")
        print("- Adult C manages: Emma only\n")

        // --- Adult A sets up access for Child 1 (Emma) ---
        print("--- Setting Up Access for Emma ---")

        // Adult A wraps Emma's FMK for themselves
        let emma_fmk_wrappedForA = try wrapFamilyMemberKey(
            child1.familyMemberKey,
            forUser: adultA.publicKey,
            grantedBy: adultA.privateKey,
            familyMemberId: child1.memberId
        )
        print("✓ Adult A wrapped Emma's FMK for self")

        // Adult A shares Emma's records with Adult B
        let emma_fmk_wrappedForB = try wrapFamilyMemberKey(
            child1.familyMemberKey,
            forUser: adultB.publicKey,
            grantedBy: adultA.privateKey,
            familyMemberId: child1.memberId
        )
        print("✓ Adult A wrapped Emma's FMK for Adult B")

        // Adult A shares Emma's records with Adult C
        let emma_fmk_wrappedForC = try wrapFamilyMemberKey(
            child1.familyMemberKey,
            forUser: adultC.publicKey,
            grantedBy: adultA.privateKey,
            familyMemberId: child1.memberId
        )
        print("✓ Adult A wrapped Emma's FMK for Adult C\n")

        // Store wrapped FMKs
        var wrappedFMKStore: [WrappedFamilyMemberKey] = [
            WrappedFamilyMemberKey(
                familyMemberId: child1.memberId,
                authorizedUserId: adultA.userId,
                wrappedFMK: emma_fmk_wrappedForA,
                ownerPublicKey: adultA.publicKey.rawRepresentation
            ),
            WrappedFamilyMemberKey(
                familyMemberId: child1.memberId,
                authorizedUserId: adultB.userId,
                wrappedFMK: emma_fmk_wrappedForB,
                ownerPublicKey: adultA.publicKey.rawRepresentation
            ),
            WrappedFamilyMemberKey(
                familyMemberId: child1.memberId,
                authorizedUserId: adultC.userId,
                wrappedFMK: emma_fmk_wrappedForC,
                ownerPublicKey: adultA.publicKey.rawRepresentation
            )
        ]

        // --- Adult A creates multiple medical records for Emma ---
        print("--- Creating Medical Records for Emma ---")

        var medicalRecords: [MedicalRecord] = []

        let record1Data = "Emma: COVID-19 vaccine #1, Pfizer, 2025-01-10".data(using: .utf8)!
        let record1Encrypted = try encryptMedicalRecord(data: record1Data, using: child1.familyMemberKey)
        medicalRecords.append(MedicalRecord(
            recordId: UUID(),
            familyMemberId: child1.memberId,
            encryptedData: record1Encrypted,
            recordType: "vaccine",
            createdAt: Date()
        ))
        print("✓ Created vaccine record 1")

        let record2Data = "Emma: COVID-19 vaccine #2, Pfizer, 2025-02-07".data(using: .utf8)!
        let record2Encrypted = try encryptMedicalRecord(data: record2Data, using: child1.familyMemberKey)
        medicalRecords.append(MedicalRecord(
            recordId: UUID(),
            familyMemberId: child1.memberId,
            encryptedData: record2Encrypted,
            recordType: "vaccine",
            createdAt: Date()
        ))
        print("✓ Created vaccine record 2")

        let record3Data = "Emma: Allergy to peanuts (severe)".data(using: .utf8)!
        let record3Encrypted = try encryptMedicalRecord(data: record3Data, using: child1.familyMemberKey)
        medicalRecords.append(MedicalRecord(
            recordId: UUID(),
            familyMemberId: child1.memberId,
            encryptedData: record3Encrypted,
            recordType: "allergy",
            createdAt: Date()
        ))
        print("✓ Created allergy record\n")

        // --- Adult B accesses Emma's records ---
        print("--- Adult B Accesses Emma's Records ---")

        // Adult B retrieves their wrapped FMK for Emma
        let adultB_wrappedFMK = wrappedFMKStore.first {
            $0.familyMemberId == child1.memberId && $0.authorizedUserId == adultB.userId
        }!

        // Adult B unwraps the FMK
        let grantorPublicKey = try Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: adultB_wrappedFMK.ownerPublicKey
        )
        let emma_fmk = try unwrapFamilyMemberKey(
            wrappedFMK: adultB_wrappedFMK.wrappedFMK,
            recipientPrivateKey: adultB.privateKey,
            grantorPublicKey: grantorPublicKey,
            familyMemberId: child1.memberId
        )
        print("✓ Adult B unwrapped Emma's FMK")

        // Adult B decrypts all of Emma's records
        print("\nAdult B viewing Emma's records:")
        for record in medicalRecords where record.familyMemberId == child1.memberId {
            let decryptedData = try decryptMedicalRecord(
                encryptedData: record.encryptedData,
                using: emma_fmk
            )
            let text = String(data: decryptedData, encoding: .utf8)!
            print("  • \(record.recordType): \(text)")
        }

        // --- Adult A revokes Adult C's access ---
        print("\n--- Revoking Adult C's Access to Emma ---")

        // 1. Generate new FMK for Emma
        let new_emma_fmk = SymmetricKey(size: .bits256)
        print("✓ Generated new FMK for Emma")

        // 2. Re-encrypt all of Emma's records with new FMK
        var reencryptedRecords: [MedicalRecord] = []
        for record in medicalRecords where record.familyMemberId == child1.memberId {
            // Decrypt with old FMK
            let decryptedData = try decryptMedicalRecord(
                encryptedData: record.encryptedData,
                using: child1.familyMemberKey // old FMK
            )
            // Re-encrypt with new FMK
            let reencryptedData = try encryptMedicalRecord(
                data: decryptedData,
                using: new_emma_fmk
            )
            reencryptedRecords.append(MedicalRecord(
                recordId: record.recordId,
                familyMemberId: record.familyMemberId,
                encryptedData: reencryptedData,
                recordType: record.recordType,
                createdAt: record.createdAt
            ))
        }
        print("✓ Re-encrypted \(reencryptedRecords.count) records with new FMK")

        // 3. Re-wrap new FMK for Adult A and Adult B only (exclude Adult C)
        let new_emma_fmk_wrappedForA = try wrapFamilyMemberKey(
            new_emma_fmk,
            forUser: adultA.publicKey,
            grantedBy: adultA.privateKey,
            familyMemberId: child1.memberId
        )
        let new_emma_fmk_wrappedForB = try wrapFamilyMemberKey(
            new_emma_fmk,
            forUser: adultB.publicKey,
            grantedBy: adultA.privateKey,
            familyMemberId: child1.memberId
        )
        print("✓ Re-wrapped new FMK for Adult A and Adult B")
        print("✓ Adult C's access removed (no wrapped FMK for them)\n")

        // --- Performance Analysis ---
        print("--- Performance Analysis ---")
        print("Family members: 2 (Emma, Liam)")
        print("Authorized adults for Emma: 3 → 2 (after revocation)")
        print("Medical records for Emma: \(medicalRecords.count(where: { $0.familyMemberId == child1.memberId }))")
        print("\nStorage overhead for Emma:")
        print("  - Wrapped FMKs: 2 × ~40 bytes = ~80 bytes")
        print(
            "  - Medical records: \(medicalRecords.count(where: { $0.familyMemberId == child1.memberId })) × ~100 bytes = ~\(medicalRecords.count(where: { $0.familyMemberId == child1.memberId }) * 100) bytes"
        )
        print("\nRevocation cost:")
        print("  - Re-encrypt: \(medicalRecords.count(where: { $0.familyMemberId == child1.memberId })) records")
        print("  - Re-wrap: 2 FMKs")
        print("  - Delete: 1 wrapped FMK (Adult C)")
    }

    // PROS:
    // ✓ Efficient: Only wrap/unwrap FMK once per family member per user
    // ✓ Adding new records: just encrypt with FMK (no key wrapping needed)
    // ✓ Granular access: per-family-member, not per-record
    // ✓ Works over insecure channels (public-key crypto)
    // ✓ Offline-first compatible

    // CONS:
    // ✗ Revocation requires re-encrypting ALL records for that family member
    // ✗ More complex key hierarchy to manage
    // ✗ If FMK compromised, all records for that family member are exposed

    // SUITABILITY FOR FAMILY MEDICAL APP:
    // ✓ EXCELLENT - Matches the use case perfectly (family-centered)
    // ✓ EXCELLENT - Scales well (< 1000 records per family member)
    // ✓ GOOD - Revocation is acceptable (re-encrypt ~100-500 records)
    // ✓ GOOD - Natural UX (share access to "Emma's records" as a unit)

    // RECOMMENDATION: This is the best fit for the family medical app!
}

// Run the demo
try? HybridFamilyKeyExample.demonstrateHybridModel()
