import SwiftUI

/// Root view: routes between onboarding and the main dashboard
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                if appState.hasCompletedOnboarding {
                    DashboardPlaceholderView()
                } else {
                    OnboardingPlaceholderView()
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

// MARK: - Placeholder Views (replaced in later steps)

struct DashboardPlaceholderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
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

            #if DEBUG
            VStack(spacing: Theme.Spacing.sm) {
                SecondaryButton("Open Settings (Test)", icon: "gear") {
                    // Placeholder for settings navigation
                }

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
        .navigationTitle("Dashboard")
    }
}

struct OnboardingPlaceholderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.mint)

            Text("Welcome to tidy")
                .font(Theme.Typography.largeTitle())
                .foregroundStyle(Theme.Colors.ink)

            Text("Free up storage by finding duplicate photos, old screenshots, large videos, and duplicate contacts.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            PrimaryButton("Get Started", icon: "arrow.right") {
                withAnimation {
                    appState.hasCompletedOnboarding = true
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Previews

#Preview("Root - Onboarding") {
    RootView()
        .environmentObject({
            let state = AppState()
            state.hasCompletedOnboarding = false
            return state
        }())
}

#Preview("Root - Dashboard") {
    RootView()
        .environmentObject({
            let state = AppState()
            state.hasCompletedOnboarding = true
            return state
        }())
}

#Preview("Root - Test Mode") {
    RootView()
        .environmentObject({
            let state = AppState()
            state.hasCompletedOnboarding = true
            state.isTestMode = true
            return state
        }())
}
