import Foundation
@testable import FamilyMedicalApp

final class MockLogExportService: LogExportServiceProtocol, @unchecked Sendable {
    var exportCalled = false
    var lastTimeWindow: LogTimeWindow?
    var resultURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("test-logs.txt")
    var shouldThrow: Error?

    func exportLogs(timeWindow: LogTimeWindow) async throws -> URL {
        exportCalled = true
        lastTimeWindow = timeWindow
        if let error = shouldThrow { throw error }
        return resultURL
    }
}
