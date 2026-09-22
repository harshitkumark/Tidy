import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = ReviewViewModel()
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if viewModel.isFinished {
                successState
            } else if viewModel.isProcessing {
                processingState
            } else {
                summaryState
            }
        }
        .navigationTitle(viewModel.isFinished ? "Done" : "Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isProcessing || viewModel.isFinished)
        .onAppear {
            viewModel.prepare(
                with: appState.cleanupSelection,
                estimatedSize: appState.cleanupSelectionSize
            )
        }
    }
    
    // MARK: - Summary (before deletion)
    
    private var summaryState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.coral)
                    
                    Text("Ready to Clean?")
                        .font(Theme.Typography.title())
                        .foregroundStyle(Theme.Colors.ink)
                    
                    Text("You're about to delete \(viewModel.totalItemCount) items. Photos and videos go to Recently Deleted for 30 days. Contact merges are permanent.")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Space freed banner
                if viewModel.totalEstimatedSize > 0 {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "externaldrive.badge.minus")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.mint)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimated space freed")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.inkSecondary)
                            Text(ByteFormatter.formatShort(viewModel.totalEstimatedSize))
                                .font(Theme.Typography.mediumNumber())
                                .foregroundStyle(Theme.Colors.mint)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Theme.Colors.mint.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                
                // Item Summary
                Card {
                    VStack(spacing: 0) {
                        if viewModel.photoCount > 0 {
                            SummaryRow(title: "Photos", count: viewModel.photoCount, icon: "photo")
                            Divider().padding(.leading, 40)
                        }
                        if viewModel.videoCount > 0 {
                            SummaryRow(title: "Videos", count: viewModel.videoCount, icon: "video")
                            Divider().padding(.leading, 40)
                        }
                        if viewModel.contactMergeCount > 0 {
                            SummaryRow(title: "Contact Merges", count: viewModel.contactMergeCount, icon: "person.2")
                        }
                    }
                }
                
                Spacer().frame(height: 20)
                
                // Confirm Button
                PrimaryButton("Confirm Deletion", icon: "trash") {
                    Task {
                        await viewModel.executeDeletion(
                            selection: appState.cleanupSelection,
                            isDryRun: appState.isTestMode && appState.isDryRun
                        ) { itemsDeleted, bytesFreed in
                            appState.lifetimeItemsDeleted += itemsDeleted
                            appState.lifetimeBytesFreed += viewModel.totalEstimatedSize
                            appState.cleanupSelection = CleanupSelection()
                            appState.cleanupSelectionSize = 0
                        }
                        // Trigger celebration
                        withAnimation(.spring(response: 0.6)) {
                            showConfetti = true
                        }
                    }
                }
                .disabled(viewModel.totalItemCount == 0)
            }
            .padding()
        }
    }
    
    // MARK: - Processing
    
    private var processingState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.mint)
            
            Text(viewModel.progressMessage)
                .font(Theme.Typography.headline())
                .foregroundStyle(Theme.Colors.ink)
            
            Text("Please don't close the app...")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
    }
    
    // MARK: - Success / Celebration
    
    private var successState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer().frame(height: 20)
                
                // Big sparkle icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.mint.opacity(0.15))
                        .frame(width: 140, height: 140)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.mint)
                        .symbolEffect(.bounce, value: showConfetti)
                }
                
                Text("Cleanup Complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.ink)
                
                // Space freed highlight
                if viewModel.totalEstimatedSize > 0 {
                    VStack(spacing: 4) {
                        Text("You freed")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        
                        Text(ByteFormatter.formatShort(viewModel.totalEstimatedSize))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.mint)
                        
                        Text("of storage space")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    .padding(.vertical)
                }
                
                // Breakdown Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        if viewModel.successfullyDeletedPhotos > 0 {
                            Label("\(viewModel.successfullyDeletedPhotos) Photos Deleted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.mint)
                        }
                        if viewModel.successfullyDeletedVideos > 0 {
                            Label("\(viewModel.successfullyDeletedVideos) Videos Deleted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.mint)
                        }
                        if viewModel.successfullyMergedContacts > 0 {
                            Label("\(viewModel.successfullyMergedContacts) Contact Groups Merged", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.mint)
                        }
                        
                        if !viewModel.errorMessages.isEmpty {
                            Divider()
                            ForEach(viewModel.errorMessages, id: \.self) { msg in
                                Label(msg, systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 20)
                
                PrimaryButton("Back to Dashboard", icon: "house") {
                    appState.shouldPopToRoot = true
                    dismiss()
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

// MARK: - Row

private struct SummaryRow: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.Colors.mint)
                .frame(width: 30)
            
            Text(title)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.ink)
            
            Spacer()
            
            Text("\(count)")
                .font(Theme.Typography.headline())
                .foregroundStyle(count > 0 ? Theme.Colors.coral : Theme.Colors.inkSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ReviewView()
            .environment(AppState())
    }
}
