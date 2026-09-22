import SwiftUI
import Observation

/// Global app state: shared selections, settings, test mode flags.
@MainActor
@Observable
final class AppState {
    // MARK: - Cleanup Selection
    var cleanupSelection = CleanupSelection()
    var cleanupSelectionSize: Int64 = 0

    // MARK: - Test Mode (DEBUG only)
    #if DEBUG
    var isTestMode: Bool = false
    var isDryRun: Bool = false
    var useMockData: Bool = false
    var showDebugOverlay: Bool = false
    var simulatedPermissionState: SimulatedPermission = .none
    #else
    let isTestMode = false
    let isDryRun = false
    let useMockData = false
    let showDebugOverlay = false
    let simulatedPermissionState: SimulatedPermission = .none
    #endif

    // MARK: - Navigation
    var shouldPopToRoot = false
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Lifetime stats
    var lifetimeItemsDeleted: Int {
        didSet { UserDefaults.standard.set(lifetimeItemsDeleted, forKey: "lifetimeItemsDeleted") }
    }
    var lifetimeBytesFreed: Int64 {
        didSet { UserDefaults.standard.set(lifetimeBytesFreed, forKey: "lifetimeBytesFreed") }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.lifetimeItemsDeleted = UserDefaults.standard.integer(forKey: "lifetimeItemsDeleted")
        self.lifetimeBytesFreed = Int64(UserDefaults.standard.integer(forKey: "lifetimeBytesFreed"))

        #if DEBUG
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
