import SwiftUI

struct LargeVideosView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: LargeVideosViewModel
    @State private var showingReview = false
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        #if DEBUG
        let useMock = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let provider = useMock ? MockPhotoLibrary() : photoProvider
        _viewModel = State(initialValue: LargeVideosViewModel(photoProvider: provider))
        #else
        _viewModel = State(initialValue: LargeVideosViewModel(photoProvider: photoProvider))
        #endif
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Scanning Videos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "video.slash",
                    title: "No Large Videos",
                    message: "You don't have any videos matching the current size filter."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.items) { item in
                            VideoRow(
                                item: item,
                                isSelected: viewModel.selectedItemIDs.contains(item.id),
                                photoProvider: appState.isTestMode && appState.useMockData ? MockPhotoLibrary() : PhotoService(),
                                onTap: { viewModel.toggleSelection(for: item.id) }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for SelectionBar
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
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Size", selection: Binding(
                        get: { viewModel.sizeFilter },
                        set: { viewModel.setFilter($0) }
                    )) {
                        ForEach(SizeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.items.isEmpty {
                    Button(viewModel.selectedCount == viewModel.items.count ? "Deselect All" : "Select All") {
                        viewModel.toggleSelectAll()
                    }
                    .font(Theme.Typography.caption())
                }
            }
        }
        .task {
            if appState.isTestMode && appState.useMockData {
                viewModel = LargeVideosViewModel(photoProvider: MockPhotoLibrary())
            }
            await viewModel.load()
        }
        .navigationDestination(isPresented: $showingReview) {
            ReviewView()
        }
    }
    
    private func reviewSelection() {
        appState.cleanupSelection.videoIdentifiers.formUnion(viewModel.selectedItemIDs)
        showingReview = true
    }
}

// MARK: - Video Row

private struct VideoRow: View {
    let item: VideoItem
    let isSelected: Bool
    let photoProvider: PhotoLibraryProviding
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: Theme.Spacing.md) {
                    // Thumbnail
                    ZStack(alignment: .bottomTrailing) {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                        } else {
                            RoundedRectangle(cornerRadius: Theme.Radius.small)
                                .fill(Theme.Colors.cloud)
                                .frame(width: 80, height: 80)
                        }
                        
                        // Duration Badge
                        Text(item.formattedDuration)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ByteFormatter.format(item.fileSize))
                            .font(Theme.Typography.headline())
                            .foregroundStyle(Theme.Colors.ink)
                        
                        if let date = item.creationDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Selection Checkmark
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.mint)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.3))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.mint, lineWidth: isSelected ? 2 : 0)
        )
        .task {
            let scale = UIScreen.main.scale
            thumbnail = await photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 80 * scale, height: 80 * scale))
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        LargeVideosView(photoProvider: MockPhotoLibrary(count: 50))
            .environment(AppState())
    }
}
