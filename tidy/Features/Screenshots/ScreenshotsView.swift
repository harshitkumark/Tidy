import SwiftUI
import Photos

struct ScreenshotsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ScreenshotsViewModel
    @State private var showingFilter = false
    @State private var showingReview = false
    
    // Grid configuration: 3 columns with minimal spacing
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        #if DEBUG
        // Inject mock library in Test Mode, otherwise use real one
        let useMock = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let provider = useMock ? MockPhotoLibrary() : photoProvider
        _viewModel = State(initialValue: ScreenshotsViewModel(photoProvider: provider))
        #else
        _viewModel = State(initialValue: ScreenshotsViewModel(photoProvider: photoProvider))
        #endif
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Scanning Screenshots...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "camera.viewfinder",
                    title: "No Screenshots Found",
                    message: "You don't have any screenshots matching the current filter."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.items) { group in
                            ScreenshotGroupView(
                                group: group,
                                isSelected: viewModel.isGroupSelected(group),
                                selectedItemIDs: viewModel.selectedItemIDs,
                                photoProvider: appState.isTestMode && appState.useMockData ? MockPhotoLibrary() : PhotoService(),
                                onToggleGroup: { viewModel.toggleGroupSelection(group) },
                                onToggleItem: { viewModel.toggleSelection(for: $0) }
                            )
                        }
                    }
                    .padding(.vertical)
                    // Bottom padding for the SelectionBar
                    .padding(.bottom, 80)
                }
            }
            
            // Selection Floating Bar
            VStack {
                Spacer()
                SelectionBar(
                    count: viewModel.selectedCount,
                    totalSize: viewModel.selectedSize,
                    actionTitle: "Review"
                ) {
                    reviewSelection()
                }
            }
        }
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.isLoading && !viewModel.items.isEmpty {
                    Button(action: {
                        let allIDs = Set(viewModel.items.flatMap(\.items).map(\.id))
                        if viewModel.selectedItemIDs == allIDs {
                            viewModel.selectedItemIDs.removeAll()
                        } else {
                            viewModel.selectedItemIDs = allIDs
                        }
                    }) {
                        Text(viewModel.selectedItemIDs.count == viewModel.items.flatMap(\.items).count ? "Deselect All" : "Select All")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.mint)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Age", selection: Binding(
                        get: { viewModel.filterAge },
                        set: { viewModel.setFilter($0) }
                    )) {
                        ForEach(AgeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            // Replace with mock if testing
            if appState.isTestMode && appState.useMockData {
                viewModel = ScreenshotsViewModel(photoProvider: MockPhotoLibrary())
            }
            await viewModel.load()
        }
        .navigationDestination(isPresented: $showingReview) {
            ReviewView()
        }
        .onChange(of: appState.shouldPopToRoot) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    private func reviewSelection() {
        appState.cleanupSelection.photoIdentifiers.formUnion(viewModel.selectedItemIDs)
        appState.cleanupSelectionSize += viewModel.selectedSize
        showingReview = true
    }
}

// MARK: - Group View

private struct ScreenshotGroupView: View {
    let group: ScreenshotGroup
    let isSelected: Bool
    let selectedItemIDs: Set<String>
    let photoProvider: PhotoLibraryProviding
    let onToggleGroup: () -> Void
    let onToggleItem: (String) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            // Group Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(Theme.Typography.headline())
                        .foregroundStyle(Theme.Colors.ink)
                    Text("\(group.items.count) items")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                Spacer()
                Button(action: onToggleGroup) {
                    Text(isSelected ? "Deselect All" : "Select All")
                        .font(Theme.Typography.caption().bold())
                        .foregroundStyle(Theme.Colors.mint)
                }
            }
            .padding(.horizontal)
            
            // Grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(group.items) { item in
                    ThumbnailCell(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        photoProvider: photoProvider,
                        onTap: { onToggleItem(item.id) }
                    )
                }
            }
        }
    }
}

// MARK: - Thumbnail Cell

private struct ThumbnailCell: View {
    let item: PhotoItem
    let isSelected: Bool
    let photoProvider: PhotoLibraryProviding
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width) // Square
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.Colors.cloud)
                }
                
                // Selection Overlay
                if isSelected {
                    Rectangle()
                        .fill(Theme.Colors.mint.opacity(0.3))
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, Theme.Colors.mint)
                        .padding(6)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .onTapGesture {
                Haptics.selection()
                onTap()
            }
            .task {
                let size = geo.size.width * UIScreen.main.scale
                thumbnail = await photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: size, height: size))
            }
        }
        .aspectRatio(1, contentMode: .fit) // Force square
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ScreenshotsView(photoProvider: MockPhotoLibrary(count: 35))
            .environment(AppState())
    }
}
