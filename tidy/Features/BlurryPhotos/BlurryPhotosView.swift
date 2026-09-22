import SwiftUI

struct BlurryPhotosView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = BlurryPhotosViewModel()
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                LoadingView(progress: viewModel.progress, message: viewModel.statusText)
            } else if viewModel.items.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
    
    @State private var showingReview = false
    
    // MARK: - Components
    
    private var emptyState: View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "eyeglasses")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.inkSecondary)
            Text("No blurry photos found!")
                .font(Theme.Typography.headline())
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
        }
    }
    
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
                        
                        ZStack(alignment: .bottomTrailing) {
                            ThumbnailView(
                                localIdentifier: item.id,
                                size: CGSize(width: 150, height: 150)
                            )
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            
                            // Dim overlay if selected
                            if isSelected {
                                Color.black.opacity(0.3)
                            }
                            
                            // Checkmark
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Theme.Colors.mint : .white.opacity(0.8))
                                .padding(6)
                        }
                        .onTapGesture {
                            viewModel.toggleSelection(for: item.id)
                        }
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
