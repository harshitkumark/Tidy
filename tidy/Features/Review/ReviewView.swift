import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = ReviewViewModel()
    
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
        .navigationBarBackButtonHidden(viewModel.isProcessing)
        .onAppear {
            viewModel.prepare(with: appState.cleanupSelection)
        }
    }
    
    // MARK: - States
    
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
                    
                    Text("You're about to delete \(viewModel.totalItemCount) items. This action cannot be undone for contacts. Photos and videos will be moved to Recently Deleted.")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Summary List
                Card {
                    VStack(spacing: 0) {
                        SummaryRow(title: "Photos", count: viewModel.photoCount, icon: "photo")
                        Divider().padding(.leading, 40)
                        SummaryRow(title: "Videos", count: viewModel.videoCount, icon: "video")
                        Divider().padding(.leading, 40)
                        SummaryRow(title: "Contact Merges", count: viewModel.contactMergeCount, icon: "person.2")
                    }
                }
                
                Spacer().frame(height: 40)
                
                // Confirm Button
                PrimaryButton("Confirm Deletion", icon: "trash") {
                    Task {
                        await viewModel.executeDeletion(
                            selection: appState.cleanupSelection,
                            isDryRun: appState.isTestMode && appState.isDryRun
                        ) { itemsDeleted, bytesFreed in
                            appState.lifetimeItemsDeleted += itemsDeleted
                            appState.lifetimeBytesFreed += bytesFreed
                            // Clear selection now that it's processed
                            appState.cleanupSelection = CleanupSelection()
                        }
                    }
                }
                .disabled(viewModel.totalItemCount == 0)
            }
            .padding()
        }
    }
    
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
    
    private var successState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.mint)
            
            Text("Cleanup Complete!")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Colors.ink)
            
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if viewModel.successfullyDeletedPhotos > 0 {
                        Text("✅ \(viewModel.successfullyDeletedPhotos) Photos Deleted")
                    }
                    if viewModel.successfullyDeletedVideos > 0 {
                        Text("✅ \(viewModel.successfullyDeletedVideos) Videos Deleted")
                    }
                    if viewModel.successfullyMergedContacts > 0 {
                        Text("✅ \(viewModel.successfullyMergedContacts) Contact Groups Merged")
                        Text("   (\(viewModel.successfullyDeletedContacts) duplicate entries removed)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    
                    if !viewModel.errorMessages.isEmpty {
                        Divider()
                        Text("Notes:")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        ForEach(viewModel.errorMessages, id: \.self) { msg in
                            Text("• \(msg)")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            Spacer()
            
            PrimaryButton("Back to Dashboard", icon: "house") {
                dismiss() // This pops back, but we also want to return to root.
                // Since this view is presented via NavigationLink, dismissing it or manipulating the nav path is needed.
                // We'll just dismiss for now, but in a real app we'd pop to root.
            }
            .padding()
        }
        .padding(.top, 40)
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
