import SwiftUI

@MainActor
@Observable
final class LargeVideosViewModel {
    // MARK: - State
    var items: [VideoItem] = []
    var selectedItemIDs: Set<String> = []
    var isLoading = true
    var sizeFilter: SizeFilter = .all
    
    // Output stats
    var selectedCount: Int { selectedItemIDs.count }
    var selectedSize: Int64 {
        items.filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let photoProvider: PhotoLibraryProviding
    private var allVideos: [VideoItem] = []
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        self.photoProvider = photoProvider
    }
    
    // MARK: - Intents
    
    func load() async {
        isLoading = true
        do {
            self.allVideos = try await photoProvider.fetchAllVideos()
            applyFilterAndSort()
        } catch {
            Logger.error("Failed to load videos: \(error)", category: .scan)
        }
        isLoading = false
    }
    
    func setFilter(_ filter: SizeFilter) {
        sizeFilter = filter
        applyFilterAndSort()
    }
    
    func toggleSelection(for itemID: String) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }
    
    func toggleSelectAll() {
        if selectedItemIDs.count == items.count {
            selectedItemIDs.removeAll()
        } else {
            selectedItemIDs = Set(items.map(\.id))
        }
    }
    
    // MARK: - Private Helpers
    
    private func applyFilterAndSort() {
        let filtered = allVideos.filter { $0.fileSize >= sizeFilter.bytes }
        // Sort by largest file size first
        self.items = filtered.sorted { $0.fileSize > $1.fileSize }
    }
}

// MARK: - Models

enum SizeFilter: String, CaseIterable, Identifiable {
    case all = "All Sizes"
    case fiftyMB = "> 50 MB"
    case hundredMB = "> 100 MB"
    case fiveHundredMB = "> 500 MB"
    case oneGB = "> 1 GB"
    
    var id: String { rawValue }
    
    var bytes: Int64 {
        switch self {
        case .all: return 0
        case .fiftyMB: return 50 * 1024 * 1024
        case .hundredMB: return 100 * 1024 * 1024
        case .fiveHundredMB: return 500 * 1024 * 1024
        case .oneGB: return 1024 * 1024 * 1024
        }
    }
}
