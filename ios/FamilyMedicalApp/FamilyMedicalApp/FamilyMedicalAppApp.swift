import SwiftUI

@main
struct FamilyMedicalAppApp: App {
    init() {
        // Handle UI testing launch arguments
        if CommandLine.arguments.contains("--uitesting") {
            if CommandLine.arguments.contains("--reset-state") {
                resetAppState()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationCoordinatorView()
        }
    }

    /// Reset app state for UI testing (delete all keychain, Core Data, and UserDefaults)
    /// This runs synchronously to ensure clean state before UI appears
    private func resetAppState() {
        let logger = LoggingService.shared.logger(category: .storage)

        // Delete all keychain items
        let keychainService = KeychainService()
        do {
            try keychainService.deleteAllItems()
        } catch {
            logger.logError(error, context: "resetAppState.deleteAllItems")
        }

        // Delete all Core Data synchronously
        do {
            try CoreDataStack.shared.deleteAllDataSync()
        } catch {
            logger.logError(error, context: "resetAppState.deleteAllDataSync")
        }

        // Clear all UserDefaults for this app
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }
}
