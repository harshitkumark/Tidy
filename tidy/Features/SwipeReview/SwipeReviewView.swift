import SwiftUI

/// Tinder-style swipe-to-keep-or-delete photo review mode.
/// Swipe right = keep, swipe left = mark for deletion.
struct SwipeReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let items: [PhotoItem]
    let photoProvider: PhotoLibraryProviding
    
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var keptIDs: Set<String> = []
    @State private var deletedIDs: Set<String> = []
    @State private var showingSummary = false
    
    private var currentItem: PhotoItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    private var progress: Double {
        guard !items.isEmpty else { return 1.0 }
        return Double(currentIndex) / Double(items.count)
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            if showingSummary {
                summaryView
            } else if let item = currentItem {
                VStack(spacing: 0) {
                    // Progress bar
                    ProgressView(value: progress)
                        .tint(Theme.Colors.mint)
                        .padding(.horizontal)
                        .padding(.top, Theme.Spacing.sm)
                    
                    HStack {
                        Text("\(currentIndex + 1) / \(items.count)")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        Spacer()
                        HStack(spacing: Theme.Spacing.md) {
                            Label("\(keptIDs.count)", systemImage: "checkmark.circle.fill")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(.green)
                            Label("\(deletedIDs.count)", systemImage: "trash.circle.fill")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.coral)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.xs)
                    
                    Spacer()
                    
                    // Card
                    SwipeCard(
                        item: item,
                        photoProvider: photoProvider,
                        offset: $offset
                    )
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    Spacer()
                    
                    // Instruction + Buttons
                    HStack(spacing: Theme.Spacing.xl) {
                        // Delete button
                        Button(action: { swipeLeft() }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.coral.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "xmark")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Theme.Colors.coral)
                            }
                        }
                        
                        // Keep button
                        Button(action: { swipeRight() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "checkmark")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                    
                    Text("Swipe left to delete · Swipe right to keep")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .padding(.bottom, Theme.Spacing.lg)
                }
            } else {
                // Finished all items - show summary
                summaryView
            }
        }
        .navigationTitle("Quick Review")
        .navigationBarTitleDisplayMode(.inline)
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    if value.translation.width > threshold {
                        swipeRight()
                    } else if value.translation.width < -threshold {
                        swipeLeft()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            offset = .zero
                        }
                    }
                }
        )
    }
    
    // MARK: - Actions
    
    private func swipeRight() {
        guard let item = currentItem else { return }
        keptIDs.insert(item.id)
        Haptics.light()
        advanceCard()
    }
    
    private func swipeLeft() {
        guard let item = currentItem else { return }
        deletedIDs.insert(item.id)
        Haptics.light()
        advanceCard()
    }
    
    private func advanceCard() {
        withAnimation(.spring(response: 0.3)) {
            offset = .zero
        }
        
        // Slight delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                } else {
                    showingSummary = true
                }
            }
        }
    }
    
    // MARK: - Summary
    
    private var summaryView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.mint)
                .symbolEffect(.bounce, options: .repeating.speed(0.5))
            
            Text("Review Complete!")
                .font(Theme.Typography.largeTitle())
                .foregroundStyle(Theme.Colors.ink)
            
            HStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: 4) {
                    Text("\(keptIDs.count)")
                        .font(Theme.Typography.bigNumber())
                        .foregroundStyle(.green)
                    Text("Kept")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                
                Rectangle()
                    .fill(Theme.Colors.inkSecondary.opacity(0.3))
                    .frame(width: 1, height: 50)
                
                VStack(spacing: 4) {
                    Text("\(deletedIDs.count)")
                        .font(Theme.Typography.bigNumber())
                        .foregroundStyle(Theme.Colors.coral)
                    Text("To Delete")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            
            let deleteSize = items.filter { deletedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
            if deleteSize > 0 {
                Text("Free up \(ByteFormatter.formatShort(deleteSize))")
                    .font(Theme.Typography.headline())
                    .foregroundStyle(Theme.Colors.mint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.mint.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            if !deletedIDs.isEmpty {
                PrimaryButton("Delete \(deletedIDs.count) Items", icon: "trash") {
                    // Pass to review
                    appState.cleanupSelection.photoIdentifiers.formUnion(deletedIDs)
                    appState.cleanupSelectionSize += items.filter { deletedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
                    dismiss()
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            
            SecondaryButton("Done", icon: "checkmark") {
                dismiss()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Swipe Card

private struct SwipeCard: View {
    let item: PhotoItem
    let photoProvider: PhotoLibraryProviding
    @Binding var offset: CGSize
    
    @State private var image: UIImage?
    
    private var rotationAngle: Double {
        Double(offset.width / 20)
    }
    
    private var swipeColor: Color {
        if offset.width > 50 {
            return .green
        } else if offset.width < -50 {
            return Theme.Colors.coral
        }
        return .clear
    }
    
    private var swipeIcon: String? {
        if offset.width > 50 {
            return "checkmark"
        } else if offset.width < -50 {
            return "xmark"
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // Photo
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.cloud)
                    .overlay {
                        ProgressView()
                    }
                    .aspectRatio(3/4, contentMode: .fit)
            }
            
            // Swipe overlay
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(swipeColor.opacity(0.2))
                .overlay {
                    if let icon = swipeIcon {
                        Image(systemName: icon)
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(swipeColor.opacity(0.7))
                    }
                }
        }
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .offset(x: offset.width)
        .rotationEffect(.degrees(rotationAngle))
        .animation(.spring(response: 0.3), value: offset)
        .task {
            image = await photoProvider.loadFullImage(for: item.id)
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        SwipeReviewView(
            items: [],
            photoProvider: MockPhotoLibrary()
        )
        .environment(AppState())
    }
}
