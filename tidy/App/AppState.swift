import SwiftUI

/// Global app state: shared selections, settings, test mode flags.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Cleanup Selection
    @Published var cleanupSelection = CleanupSelection()

    // MARK: - Test Mode (DEBUG only)
    #if DEBUG
    @Published var isTestMode: Bool = false
    @Published var isDryRun: Bool = false
    @Published var useMockData: Bool = false
    @Published var showDebugOverlay: Bool = false
    @Published var simulatedPermissionState: SimulatedPermission = .none
    #else
    let isTestMode = false
    let isDryRun = false
    let useMockData = false
    let showDebugOverlay = false
    let simulatedPermissionState: SimulatedPermission = .none
    #endif

    // MARK: - Navigation
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Lifetime stats
    @Published var lifetimeItemsDeleted: Int {
        didSet { UserDefaults.standard.set(lifetimeItemsDeleted, forKey: "lifetimeItemsDeleted") }
    }
    @Published var lifetimeBytesFreed: Int64 {
        didSet { UserDefaults.standard.set(lifetimeBytesFreed, forKey: "lifetimeBytesFreed") }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.lifetimeItemsDeleted = UserDefaults.standard.integer(forKey: "lifetimeItemsDeleted")
        self.lifetimeBytesFreed = Int64(UserDefaults.standard.integer(forKey: "lifetimeBytesFreed"))

        #if DEBUG
        // Check launch argument for test mode
        if CommandLine.arguments.contains("-tidyTestMode") {
            isTestMode = true
        }
        #endif
    }

    func clearSelection() {
        cleanupSelection = CleanupSelection()
    }
}

/// Simulated permission states for Test Mode
enum SimulatedPermission: String, CaseIterable, Sendable {
    case none = "System Default"
    case authorized = "Authorized"
    case denied = "Denied"
    case limited = "Limited"
    case restricted = "Restricted"
}
