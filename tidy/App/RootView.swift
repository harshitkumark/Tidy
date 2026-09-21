import SwiftUI

/// Root view: routes between onboarding and the main dashboard.
/// Monitors scene phase to refresh permissions when returning from Settings.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var permissionService = PermissionService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                if appState.hasCompletedOnboarding {
                    DashboardPlaceholderView()
                        .environment(permissionService)
                } else {
                    OnboardingView()
                        .environment(permissionService)
                }

                // Test Mode pill (DEBUG only)
                #if DEBUG
                if appState.isTestMode {
                    VStack {
                        TestModePill()
                        Spacer()
                    }
                }
                #endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionService.handleScenePhaseActive()
            }
        }
    }
}

// MARK: - Test Mode Pill

#if DEBUG
struct TestModePill: View {
    var body: some View {
        Text("TEST MODE")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.Colors.testModePill)
            .clipShape(Capsule())
            .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
    }
}
#endif

// MARK: - Placeholder Dashboard (replaced in Step 3)

struct DashboardPlaceholderView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionService.self) private var permissionService

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Colors.mint)

                Text("tidy")
                    .font(Theme.Typography.largeTitle())
                    .foregroundStyle(Theme.Colors.ink)

                Text("Your storage dashboard will appear here")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .multilineTextAlignment(.center)

                // Show permission states for debugging
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    PermissionStatusRow(name: "Photos", status: permissionService.photoStatus)
                    PermissionStatusRow(name: "Contacts", status: permissionService.contactStatus)
                    PermissionStatusRow(name: "Calendar", status: permissionService.calendarStatus)
                }
                .padding(.top, Theme.Spacing.md)

                // Limited access banner
                if permissionService.photoStatus == .limited {
                    LimitedAccessBanner(
                        photoCount: permissionService.limitedPhotoCount,
                        onManage: {
                            // Will present limited library picker
                        },
                        onOpenSettings: {
                            permissionService.openAppSettings()
                        }
                    )
                    .padding(.horizontal)
                }

                // Denied state
                if permissionService.photoStatus == .denied {
                    PermissionBanner(
                        message: "Photo access is needed to find duplicates",
                        actionTitle: "Open Settings"
                    ) {
                        permissionService.openAppSettings()
                    }
                    .padding(.horizontal)
                }

                #if DEBUG
                VStack(spacing: Theme.Spacing.sm) {
                    if !appState.isTestMode {
                        SecondaryButton("Enable Test Mode", icon: "ant") {
                            appState.isTestMode = true
                        }
                    }
                }
                .padding(.top, Theme.Spacing.md)
                #endif
            }
            .padding(Theme.Spacing.xl)
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Permission Status Row (temporary debug helper)

private struct PermissionStatusRow: View {
    let name: String
    let status: PermissionStatus

    var body: some View {
        HStack {
            Text(name)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            Text(status.rawValue)
                .font(Theme.Typography.caption())
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized: return .green
        case .limited: return .orange
        case .denied, .restricted: return Theme.Colors.coral
        case .notDetermined: return Theme.Colors.inkSecondary
        }
    }
}

// MARK: - Previews

#Preview("Root - Onboarding") {
    RootView()
        .environment({
            let state = AppState()
            state.hasCompletedOnboarding = false
            return state
        }())
}

#Preview("Root - Dashboard") {
    RootView()
        .environment({
            let state = AppState()
            state.hasCompletedOnboarding = true
            return state
        }())
}
