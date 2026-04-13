import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("OrphanBlobCleanupService Tests")
struct OrphanBlobCleanupServiceTests {
    // MARK: - Fixtures

    private struct Fixture {
        let service: OrphanBlobCleanupService
        let blobService: MockDocumentBlobService
        let queryService: MockDocumentReferenceQueryService
        let personId: UUID
        let primaryKey: SymmetricKey
    }

    private static func makeFixture() -> Fixture {
        let blobService = MockDocumentBlobService()
        let queryService = MockDocumentReferenceQueryService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        let service = OrphanBlobCleanupService(
            blobService: blobService,
            queryService: queryService
        )
        return Fixture(
            service: service,
            blobService: blobService,
            queryService: queryService,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    // MARK: - cleanOrphans

    @Test("cleanOrphans deletes blobs not referenced by any record")
    func cleanOrphans_deletesOrphans() async throws {
        let fixture = Self.makeFixture()
        let orphanHMAC = Data([0x01, 0x02])
        let referencedHMAC = Data([0x03, 0x04])

        fixture.blobService.blobsOnDisk[fixture.personId] = [orphanHMAC, referencedHMAC]
        fixture.blobService.blobSizes[orphanHMAC] = 2_048
        fixture.queryService.allReferencedHMACsResult = [referencedHMAC]

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 2_048)
        #expect(fixture.blobService.deleteDirectCalls.count == 1)
        #expect(fixture.blobService.deleteDirectCalls.first?.contentHMAC == orphanHMAC)
    }

    @Test("cleanOrphans returns zero when no orphans exist")
    func cleanOrphans_noOrphans() async throws {
        let fixture = Self.makeFixture()
        let referencedHMAC = Data([0x01, 0x02])

        fixture.blobService.blobsOnDisk[fixture.personId] = [referencedHMAC]
        fixture.queryService.allReferencedHMACsResult = [referencedHMAC]

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 0)
        #expect(result.freedBytes == 0)
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("cleanOrphans returns zero when person has no blobs")
    func cleanOrphans_emptyDirectory() async throws {
        let fixture = Self.makeFixture()
        fixture.blobService.blobsOnDisk[fixture.personId] = []
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 0)
        #expect(result.freedBytes == 0)
    }

    @Test("cleanOrphans skips in-flight blobs")
    func cleanOrphans_skipsInFlight() async throws {
        let fixture = Self.makeFixture()
        let orphanHMAC = Data([0x01, 0x02])
        let inFlightHMAC = Data([0x03, 0x04])

        fixture.blobService.blobsOnDisk[fixture.personId] = [orphanHMAC, inFlightHMAC]
        fixture.blobService.blobSizes[orphanHMAC] = 1_024
        fixture.blobService.inFlightHMACs = [inFlightHMAC]
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 1_024)
        let deletedHMACs = fixture.blobService.deleteDirectCalls.map(\.contentHMAC)
        #expect(deletedHMACs.contains(orphanHMAC))
        #expect(!deletedHMACs.contains(inFlightHMAC))
    }

    @Test("cleanOrphans continues after individual delete failure and counts partial success")
    func cleanOrphans_partialFailure() async throws {
        let fixture = Self.makeFixture()
        let failingHMAC = Data([0x01])
        let succeedingHMAC = Data([0x02])

        fixture.blobService.blobsOnDisk[fixture.personId] = [failingHMAC, succeedingHMAC]
        fixture.blobService.blobSizes[failingHMAC] = 512
        fixture.blobService.blobSizes[succeedingHMAC] = 1_024
        fixture.queryService.allReferencedHMACsResult = []
        fixture.blobService.deleteDirectFailForHMACs = [failingHMAC]

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(fixture.blobService.deleteDirectCalls.count == 2)
        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 1_024)
    }

    @Test("cleanOrphans propagates listBlobs errors")
    func cleanOrphans_propagatesListBlobsError() async throws {
        let fixture = Self.makeFixture()
        fixture.blobService.listBlobsError = ModelError.documentStorageFailed(reason: "list failed")
        fixture.queryService.allReferencedHMACsResult = []

        await #expect(throws: ModelError.self) {
            _ = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)
        }
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("cleanOrphans propagates allReferencedHMACs errors")
    func cleanOrphans_propagatesAllReferencedHMACsError() async throws {
        let fixture = Self.makeFixture()
        fixture.queryService.allReferencedHMACsError = ModelError.documentStorageFailed(reason: "query failed")
        fixture.blobService.blobsOnDisk[fixture.personId] = [Data([0x01])]

        await #expect(throws: ModelError.self) {
            _ = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)
        }
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("cleanOrphans skips blobs whose size lookup fails but continues scanning")
    func cleanOrphans_blobSizeFailureIsTreatedAsPartialFailure() async throws {
        let fixture = Self.makeFixture()
        let sizeFailHMAC = Data([0x01])
        let goodHMAC = Data([0x02])

        fixture.blobService.blobsOnDisk[fixture.personId] = [sizeFailHMAC, goodHMAC]
        fixture.blobService.blobSizes[goodHMAC] = 2_048
        fixture.blobService.blobSizeFailForHMACs = [sizeFailHMAC]
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.cleanOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        // Only the good HMAC is counted and deleted; the size-fail HMAC is skipped.
        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 2_048)
        let deletedHMACs = fixture.blobService.deleteDirectCalls.map(\.contentHMAC)
        #expect(deletedHMACs.contains(goodHMAC))
        #expect(!deletedHMACs.contains(sizeFailHMAC))
    }

    // MARK: - countOrphans

    @Test("countOrphans reports counts without deleting")
    func countOrphans_dryRun() async throws {
        let fixture = Self.makeFixture()
        let orphanHMAC = Data([0x01, 0x02])

        fixture.blobService.blobsOnDisk[fixture.personId] = [orphanHMAC]
        fixture.blobService.blobSizes[orphanHMAC] = 4_096
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.countOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 4_096)
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("countOrphans skips in-flight blobs without deleting")
    func countOrphans_skipsInFlight() async throws {
        let fixture = Self.makeFixture()
        let orphanHMAC = Data([0x01, 0x02])
        let inFlightHMAC = Data([0x03, 0x04])

        fixture.blobService.blobsOnDisk[fixture.personId] = [orphanHMAC, inFlightHMAC]
        fixture.blobService.blobSizes[orphanHMAC] = 1_024
        fixture.blobService.blobSizes[inFlightHMAC] = 4_096
        fixture.blobService.inFlightHMACs = [inFlightHMAC]
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.countOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 1_024)
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("countOrphans propagates listBlobs errors")
    func countOrphans_propagatesErrors() async throws {
        let fixture = Self.makeFixture()
        fixture.blobService.listBlobsError = ModelError.documentStorageFailed(reason: "list failed")
        fixture.queryService.allReferencedHMACsResult = []

        await #expect(throws: ModelError.self) {
            _ = try await fixture.service.countOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)
        }
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }

    @Test("countOrphans skips blobs whose size lookup fails")
    func countOrphans_blobSizeFailureIsSkipped() async throws {
        let fixture = Self.makeFixture()
        let sizeFailHMAC = Data([0x01])
        let goodHMAC = Data([0x02])

        fixture.blobService.blobsOnDisk[fixture.personId] = [sizeFailHMAC, goodHMAC]
        fixture.blobService.blobSizes[goodHMAC] = 2_048
        fixture.blobService.blobSizeFailForHMACs = [sizeFailHMAC]
        fixture.queryService.allReferencedHMACsResult = []

        let result = try await fixture.service.countOrphans(personId: fixture.personId, primaryKey: fixture.primaryKey)

        // One bad blob doesn't poison the whole scan; the usable ones still count.
        #expect(result.orphanCount == 1)
        #expect(result.freedBytes == 2_048)
        #expect(fixture.blobService.deleteDirectCalls.isEmpty)
    }
}
