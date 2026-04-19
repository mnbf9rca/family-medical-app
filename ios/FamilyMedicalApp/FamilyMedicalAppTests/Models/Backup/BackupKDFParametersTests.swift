import Testing
@testable import FamilyMedicalApp

/// Pins `BackupKDF.defaultArgon2id` to ADR-0002 §"Argon2id Parameters".
///
/// If either the ADR or the implementation drifts without the other, this
/// test fails. The constants below ARE the source of truth for this
/// assertion; any change MUST be reflected in
/// `docs/adr/adr-0002-key-hierarchy.md` first.
struct BackupKDFParametersTests {
    // Pinned to ADR-0002. Update together.
    private static let adr0002Memory: Int = 64 * 1_024 * 1_024 // 64 MB = 67,108,864 bytes
    private static let adr0002Iterations: Int = 3
    private static let adr0002Parallelism: Int = 1
    private static let adr0002KeyLength: Int = 32 // 256-bit key

    @Test
    func defaultArgon2idMatchesADR0002() {
        let kdf = BackupKDF.defaultArgon2id
        #expect(kdf.memory == Self.adr0002Memory)
        #expect(kdf.iterations == Self.adr0002Iterations)
        #expect(kdf.parallelism == Self.adr0002Parallelism)
        #expect(kdf.keyLength == Self.adr0002KeyLength)
    }
}
