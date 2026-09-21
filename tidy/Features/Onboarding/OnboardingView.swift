import SwiftUI

/// Onboarding flow: value prop → photo permission rationale → contacts rationale
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @State private var permissionService = PermissionService()

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomePage(onContinue: { currentPage = 1 })
                    .tag(0)

                PhotoPermissionPage(
                    permissionService: permissionService,
                    onContinue: { currentPage = 2 }
                )
                .tag(1)

                ContactPermissionPage(
                    permissionService: permissionService,
                    onComplete: { completeOnboarding() }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Page indicator
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == currentPage ? Theme.Colors.mint : Theme.Colors.ink.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.hasCompletedOnboarding = true
        }
        Haptics.success()
    }
}

// MARK: - Page 1: Welcome / Value Proposition

private struct WelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(Theme.Colors.mint)
                .symbolEffect(.pulse, options: .repeating)

            Text("tidy")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.ink)

            Text("Free up space on your iPhone")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                FeatureRow(icon: "photo.on.rectangle.angled", text: "Find similar & duplicate photos")
                FeatureRow(icon: "camera.viewfinder", text: "Clean up old screenshots")
                FeatureRow(icon: "video", text: "Spot large videos eating storage")
                FeatureRow(icon: "person.2", text: "Merge duplicate contacts")
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                    Text("Everything stays on your phone. No data ever leaves.")
                        .font(Theme.Typography.caption())
                }
                .foregroundStyle(Theme.Colors.inkSecondary)

                PrimaryButton("Get Started", icon: "arrow.right", action: onContinue)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Page 2: Photo Permission

private struct PhotoPermissionPage: View {
    let permissionService: PermissionService
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.mint)

            Text("Access Your Photos")
                .font(Theme.Typography.largeTitle())
                .foregroundStyle(Theme.Colors.ink)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ReasonRow(icon: "magnifyingglass", text: "Scan for duplicates and similar shots")
                ReasonRow(icon: "arrow.up.right.square", text: "Calculate file sizes to find what takes space")
                ReasonRow(icon: "eye.slash", text: "Nothing is uploaded — analysis happens on your device")
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Card {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Theme.Colors.mint)
                    Text("You stay in control. Nothing is deleted without your review and confirmation.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton("Allow Photo Access") {
                    Task {
                        await permissionService.requestPhotoAccess()
                        onContinue()
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Button("Not now") {
                    onContinue()
                }
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Page 3: Contact Permission

private struct ContactPermissionPage: View {
    let permissionService: PermissionService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.mint)

            Text("Access Your Contacts")
                .font(Theme.Typography.largeTitle())
                .foregroundStyle(Theme.Colors.ink)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ReasonRow(icon: "person.2", text: "Find duplicate contacts with matching names or phone numbers")
                ReasonRow(icon: "arrow.triangle.merge", text: "Merge duplicates into one clean entry")
                ReasonRow(icon: "lock.fill", text: "Contacts stay on your device, always")
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Card {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Theme.Colors.mint)
                    Text("Before any merge, you can export a backup of your contacts.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton("Allow Contact Access") {
                    Task {
                        await permissionService.requestContactAccess()
                        onComplete()
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Button("Skip for now") {
                    onComplete()
                }
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Helper Components

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.Colors.mint)
                .frame(width: 32)

            Text(text)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.ink)
        }
    }
}

private struct ReasonRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.mint)
                .frame(width: 24)

            Text(text)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.ink)
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView()
        .environment(AppState())
}
