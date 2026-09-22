import SwiftUI

struct BlurryPhotosView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BlurryPhotosViewModel()
    @State private var showingReview = false
    @State private var showingQuickReview = false
    
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
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "eyeglasses",
                    title: "No Blurry Photos",
                    message: "Your library looks crisp! We couldn't find any blurry photos."
                )
            } else {
                content
            }
        }
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !viewModel.isLoading && !viewModel.items.isEmpty {
                        Button { showingQuickReview = true } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    
                    if !viewModel.isLoading && !viewModel.items.isEmpty {
                        Button(action: {
                            if viewModel.selectedCount == viewModel.items.count {
                                viewModel.selectedItemIDs.removeAll()
                            } else {
                                viewModel.selectedItemIDs = Set(viewModel.items.map(\.id))
                            }
                        }) {
                            Text(viewModel.selectedCount == viewModel.items.count ? "Deselect All" : "Select All")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.mint)
                        }
                    }
                }
            }
        }
        .task {
            if appState.isTestMode && appState.useMockData {
                viewModel = BlurryPhotosViewModel(photoProvider: MockPhotoLibrary())
            }
            viewModel.load()
        }
        .onDisappear {
            viewModel.cancelScan()
        }
    }
    
    // MARK: - Components
    
    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(viewModel.items) { item in
                        let isSelected = viewModel.selectedItemIDs.contains(item.id)
                        
                        BlurryPhotoCell(
                            item: item,
                            isSelected: isSelected,
                            photoProvider: appState.isTestMode && appState.useMockData ? MockPhotoLibrary() : PhotoService(),
                            onTap: { viewModel.toggleSelection(for: item.id) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Footer
            VStack(spacing: Theme.Spacing.sm) {
                Divider()
                HStack {
                    Text("\(viewModel.selectedCount) Selected")
                        .font(Theme.Typography.headline())
                        .foregroundStyle(Theme.Colors.ink)
                    
                    Spacer()
                    
                    Text(ByteFormatter.formatShort(viewModel.selectedSize))
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.coral)
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                
                PrimaryButton("Review \(viewModel.selectedCount) Items", icon: "trash") {
                    reviewSelection()
                }
                .disabled(viewModel.selectedCount == 0)
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
        }
        .navigationDestination(isPresented: $showingReview) {
            ReviewView()
        }
        .navigationDestination(isPresented: $showingQuickReview) {
            SwipeReviewView(
                items: viewModel.items,
                photoProvider: appState.isTestMode && appState.useMockData ? MockPhotoLibrary() : PhotoService()
            )
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

// MARK: - Blurry Photo Cell

private struct BlurryPhotoCell: View {
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
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.Colors.inkSecondary.opacity(0.2))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay {
                            ProgressView()
                        }
                }
                
                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: geo.size.width, height: geo.size.width)
                }
                
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.Colors.mint : .white.opacity(0.8))
                    .padding(6)
            }
            .onTapGesture {
                onTap()
            }
            .task {
                let scale = UIScreen.main.scale
                let size = geo.size.width * scale
                thumbnail = await photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: size, height: size))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
