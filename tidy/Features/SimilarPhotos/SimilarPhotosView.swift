import SwiftUI

struct SimilarPhotosView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SimilarPhotosViewModel
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        #if DEBUG
        let useMock = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let provider = useMock ? MockPhotoLibrary() : photoProvider
        _viewModel = State(initialValue: SimilarPhotosViewModel(photoProvider: provider))
        #else
        _viewModel = State(initialValue: SimilarPhotosViewModel(photoProvider: photoProvider))
        #endif
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressRing(progress: viewModel.progress, size: 120)
                    Text(viewModel.statusText)
                        .font(Theme.Typography.headline())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.groups.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "No Similar Photos",
                    message: "Your library looks clean! We couldn't find any duplicate or similar photos."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.groups) { group in
                            SimilarGroupView(
                                group: group,
                                selectedItemIDs: viewModel.selectedItemIDs,
                                photoProvider: appState.isTestMode && appState.useMockData ? MockPhotoLibrary() : PhotoService(),
                                onToggleItem: { viewModel.toggleSelection(for: $0) },
                                onKeepBest: { viewModel.keepBest(in: group) },
                                onKeepAll: { viewModel.keepAll(in: group) }
                            )
                        }
                    }
                    .padding(.vertical)
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
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if appState.isTestMode && appState.useMockData {
                viewModel = SimilarPhotosViewModel(photoProvider: MockPhotoLibrary())
            }
            await viewModel.startScanIfNeeded()
        }
    }
    
    private func reviewSelection() {
        appState.cleanupSelection.photoIdentifiers.formUnion(viewModel.selectedItemIDs)
        // TODO: Navigate to Review View
        Logger.info("Ready for Review: \(viewModel.selectedItemIDs.count) similar photos", category: .general)
    }
}

// MARK: - Group View

private struct SimilarGroupView: View {
    let group: PhotoGroup
    let selectedItemIDs: Set<String>
    let photoProvider: PhotoLibraryProviding
    let onToggleItem: (String) -> Void
    let onKeepBest: () -> Void
    let onKeepAll: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Text("\(group.items.count) Similar")
                    .font(Theme.Typography.headline())
                    .foregroundStyle(Theme.Colors.ink)
                
                Spacer()
                
                Menu {
                    Button("Keep Best Only", action: onKeepBest)
                    Button("Keep All", action: onKeepAll)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .padding(.horizontal)
            
            // Horizontal Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    Spacer().frame(width: Theme.Spacing.sm) // leading padding
                    
                    ForEach(group.items) { item in
                        let isBest = item.id == group.bestItemID
                        let isSelected = selectedItemIDs.contains(item.id)
                        
                        SimilarPhotoCell(
                            item: item,
                            isBest: isBest,
                            isSelected: isSelected,
                            photoProvider: photoProvider,
                            onTap: { onToggleItem(item.id) }
                        )
                    }
                    
                    Spacer().frame(width: Theme.Spacing.sm) // trailing padding
                }
            }
            
            // Footer Info
            HStack {
                if group.reclaimableSize > 0 {
                    Text("Can save \(ByteFormatter.formatShort(group.reclaimableSize))")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.mint)
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Cell

private struct SimilarPhotoCell: View {
    let item: PhotoItem
    let isBest: Bool
    let isSelected: Bool
    let photoProvider: PhotoLibraryProviding
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.Colors.cloud)
                        .frame(width: 140, height: 140)
                }
                
                // Badges
                HStack {
                    if isBest {
                        Text("BEST")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.mint)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, Theme.Colors.coral)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .padding(6)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .stroke(isSelected ? Theme.Colors.coral : Color.clear, lineWidth: 3)
        )
        .task {
            let scale = UIScreen.main.scale
            thumbnail = await photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 140 * scale, height: 140 * scale))
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        SimilarPhotosView(photoProvider: MockPhotoLibrary(count: 35))
            .environment(AppState())
    }
}
