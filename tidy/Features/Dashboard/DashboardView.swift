import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionService.self) private var permissionService
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
                    .padding(.top, Theme.Spacing.md)

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
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    #if DEBUG
                    Button(action: { appState.isTestMode.toggle() }) {
                        Image(systemName: "ant")
                            .foregroundStyle(appState.isTestMode ? .orange : Theme.Colors.inkSecondary)
                    }
                    #endif
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
                case .duplicateContacts:
                    Text("Duplicate Contacts (Step 9)").navigationTitle("Contacts")
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
        }
    }
}

// MARK: - Subviews

private struct StorageRingSection: View {
    let storageInfo: StorageInfo?
    let totalReclaimable: Int64

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                ProgressRing(
                    progress: storageInfo?.usedFraction ?? 0,
                    lineWidth: 16,
                    size: 200,
                    gradientColors: [Theme.Colors.mint, Theme.Colors.mint.opacity(0.4)]
                )

                VStack(spacing: 4) {
                    if let info = storageInfo {
                        Text(ByteFormatter.formatShort(info.usedCapacity))
                            .font(Theme.Typography.bigNumber())
                            .foregroundStyle(Theme.Colors.ink)
                        Text("used of \(ByteFormatter.formatShort(info.totalCapacity))")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    } else {
                        SkeletonView()
                            .frame(width: 100, height: 40)
                        SkeletonView()
                            .frame(width: 80, height: 16)
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.sm)

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
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundStyle(category.iconColor)
                        Spacer()
                        if category.permissionNeeded {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.coral)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
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
                            if let reclaimable = category.reclaimableSize {
                                Text("Can free \(ByteFormatter.formatShort(reclaimable))")
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.mint)
                            } else if let count = category.count {
                                Text("\(count) items")
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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
