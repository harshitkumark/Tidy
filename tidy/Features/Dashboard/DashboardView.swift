import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionService.self) private var permissionService
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = DashboardViewModel()

    // Navigation paths for later steps
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Top Storage Ring
                    StorageRingSection(
                        storageInfo: viewModel.storageInfo,
                        totalReclaimable: viewModel.totalReclaimable
                    )

                    // Categories Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                        ForEach(viewModel.categories) { category in
                            CategoryCard(category: category) {
                                if category.permissionNeeded {
                                    permissionService.openAppSettings()
                                } else if !category.isLoading {
                                    navigationPath.append(category.destination)
                                }
                            }
                        }
                    }

                    // Honest Footer
                    Text("tidy only manages your photos, videos and contacts. iOS doesn't allow cleaning other apps' data.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.lg)
                        .padding(.horizontal)

                    // Debug Overrides
                    #if DEBUG
                    if appState.isTestMode {
                        TestModeDashboardControls()
                    }
                    #endif
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("tidy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    #if DEBUG
                    Button(action: { appState.isTestMode.toggle() }) {
                        Image(systemName: "ladybug.fill")
                            .foregroundStyle(appState.isTestMode ? Theme.Colors.coral : Theme.Colors.inkSecondary)
                    }
                    #endif
                }
            }
            .onChange(of: appState.shouldPopToRoot) { _, newValue in
                if newValue {
                    navigationPath.removeLast(navigationPath.count)
                    appState.shouldPopToRoot = false
                }
            }
            .navigationDestination(for: DashboardDestination.self) { destination in
                // Placeholders for future steps
                switch destination {
                case .similarPhotos:
                    SimilarPhotosView()
                case .screenshots:
                    ScreenshotsView()
                case .largeVideos:
                    LargeVideosView()
                case .blurryPhotos:
                    BlurryPhotosView()
                case .duplicateContacts:
                    DuplicateContactsView()
                case .videoCompression:
                    VideoCompressionView()
                case .privateVault:
                    PrivateVaultView()
                case .testMode:
                    #if DEBUG
                    TestModeView()
                    #else
                    EmptyView()
                    #endif
                }
            }
            .onAppear {
                viewModel.load()
            }
            .onChange(of: permissionService.photoStatus) { _, newStatus in
                viewModel.updatePermissionStates(photoStatus: newStatus, contactStatus: permissionService.contactStatus)
            }
            .onChange(of: permissionService.contactStatus) { _, newStatus in
                viewModel.updatePermissionStates(photoStatus: permissionService.photoStatus, contactStatus: newStatus)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.load()
                }
            }
            .onChange(of: appState.lifetimeItemsDeleted) { _, _ in
                // Refresh data when user finishes a cleanup in the Review screen
                viewModel.load()
            }
        }
    }
}

// MARK: - Subviews

private struct StorageRingSection: View {
    let storageInfo: StorageInfo?
    let totalReclaimable: Int64

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                // Outer glow for premium feel
                Circle()
                    .fill(Theme.Colors.mint.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 15)
                
                ProgressRing(
                    progress: storageInfo?.usedFraction ?? 0,
                    lineWidth: 16,
                    size: 180,
                    gradientColors: [Theme.Colors.mint, Color.teal]
                )
                .shadow(color: Theme.Colors.mint.opacity(0.25), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    if let info = storageInfo {
                        Text(ByteFormatter.formatShort(info.usedCapacity))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 30)
                        
                        Text("used of \(ByteFormatter.formatShort(info.totalCapacity))")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    } else {
                        SkeletonView()
                            .frame(width: 100, height: 40)
                        SkeletonView()
                            .frame(width: 70, height: 14)
                    }
                }
            }
            .padding(.top, Theme.Spacing.sm)

            if totalReclaimable > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.Colors.mint)
                    Text("Can free up \(ByteFormatter.formatShort(totalReclaimable))")
                        .font(Theme.Typography.headline())
                        .foregroundStyle(Theme.Colors.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.Colors.mint.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

private struct CategoryCard: View {
    let category: CategoryCardData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    HStack {
                        // Icon with a tinted circular background
                        ZStack {
                            Circle()
                                .fill(category.iconColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: category.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(category.iconColor)
                        }
                        
                        Spacer()
                        
                        if category.permissionNeeded {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.coral)
                                .padding(8)
                                .background(Theme.Colors.coral.opacity(0.1))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.title)
                            .font(Theme.Typography.headline())
                            .foregroundStyle(Theme.Colors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if category.permissionNeeded {
                            Text("Allow access")
                                .font(Theme.Typography.caption().bold())
                                .foregroundStyle(Theme.Colors.coral)
                        } else if category.isLoading {
                            SkeletonView()
                                .frame(height: 14)
                                .frame(width: 60)
                        } else {
                            if let reclaimable = category.reclaimableSize, reclaimable > 0 {
                                Text("Can free \(ByteFormatter.formatShort(reclaimable))")
                                    .font(Theme.Typography.caption().weight(.medium))
                                    .foregroundStyle(Theme.Colors.mint)
                            } else if let count = category.count, count > 0 {
                                Text("\(count) items")
                                    .font(Theme.Typography.caption().weight(.medium))
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            } else if category.count == 0 || category.reclaimableSize == 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Clean")
                                }
                                .font(Theme.Typography.caption().weight(.bold))
                                .foregroundStyle(Theme.Colors.mint)
                            } else {
                                Text("Tap to scan")
                                    .font(Theme.Typography.caption().weight(.medium))
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(category.permissionNeeded ? 0.8 : 1.0)
    }
}

// MARK: - Test Mode Controls

#if DEBUG
private struct TestModeDashboardControls: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Divider()
                .padding(.vertical, Theme.Spacing.sm)
            Text("Test Mode Options")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            
            NavigationLink(value: DashboardDestination.testMode) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "gear")
                        .font(.body.weight(.medium))
                    Text("Open Test Settings & Seeders")
                        .font(Theme.Typography.headline())
                }
                .foregroundStyle(Theme.Colors.mint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.mint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            
            SecondaryButton("Reset Permissions (Settings)", icon: "lock") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
#endif

// MARK: - Previews

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(PermissionService())
}
