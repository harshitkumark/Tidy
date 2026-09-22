import SwiftUI

struct VideoCompressionView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = VideoCompressionViewModel()
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.videos.isEmpty {
                    emptyState
                } else {
                    videoPickerList
                    
                    Spacer()
                    
                    compressionControls
                }
            }
        }
        .navigationTitle("Compress Videos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Mock support
            if appState.isTestMode && appState.useMockData {
                viewModel = VideoCompressionViewModel(photoProvider: MockPhotoLibrary())
            }
            await viewModel.load()
        }
    }
    
    // MARK: - Components
    
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "video.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.inkSecondary)
            Text("No large videos found")
                .font(Theme.Typography.headline())
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
        }
    }
    
    private var videoPickerList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.videos) { video in
                    Button(action: { viewModel.selectedVideoID = video.id }) {
                        HStack(spacing: Theme.Spacing.md) {
                            // Thumbnail placeholder
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.Colors.inkSecondary.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "video.fill")
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.formattedDuration)
                                    .font(Theme.Typography.body())
                                    .foregroundStyle(Theme.Colors.ink)
                                
                                Text(ByteFormatter.formatShort(video.fileSize))
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedVideoID == video.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.mint)
                            } else {
                                Image(systemName: "circle")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .fill(viewModel.selectedVideoID == video.id ? Theme.Colors.mint.opacity(0.1) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(viewModel.selectedVideoID == video.id ? Theme.Colors.mint : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var compressionControls: some View {
        Card {
            VStack(spacing: Theme.Spacing.lg) {
                // Quality Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Quality")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    
                    Picker("Quality", selection: $viewModel.selectedQuality) {
                        ForEach(VideoCompressionService.CompressionQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isCompressing)
                }
                
                // Stats Preview
                if let selected = viewModel.videos.first(where: { $0.id == viewModel.selectedVideoID }) {
                    let estCompressedSize = Int64(Double(selected.fileSize) * viewModel.selectedQuality.estimatedRatio)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Original")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                            Text(ByteFormatter.formatShort(selected.fileSize))
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.coral)
                        }
                        
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Estimated")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                            Text(ByteFormatter.formatShort(estCompressedSize))
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.mint)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if let msg = viewModel.errorMsg {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.coral)
                }
                
                if let msg = viewModel.successMsg {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.mint)
                }
                
                if viewModel.isCompressing {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress)
                            .tint(Theme.Colors.mint)
                        Text("Compressing... \(Int(viewModel.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                } else {
                    PrimaryButton("Start Compression", icon: "arrow.down.right.and.arrow.up.left") {
                        Task {
                            await viewModel.compressSelected(isDryRun: appState.isTestMode && appState.isDryRun)
                        }
                    }
                    .disabled(viewModel.selectedVideoID == nil)
                }
            }
        }
    }
}
