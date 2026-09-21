import SwiftUI
import Photos

@MainActor
@Observable
final class ScreenshotsViewModel {
    // MARK: - State
    var items: [ScreenshotGroup] = []
    var selectedItemIDs: Set<String> = []
    var isLoading = true
    var filterAge: AgeFilter = .oneMonth
    
    // Output stats
    var selectedCount: Int { selectedItemIDs.count }
    var selectedSize: Int64 {
        let allItems = items.flatMap(\.items)
        return allItems.filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let photoProvider: PhotoLibraryProviding
    private var allScreenshots: [PhotoItem] = []
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        self.photoProvider = photoProvider
    }
    
    // MARK: - Intents
    
    func load() async {
        isLoading = true
        do {
            let allPhotos = try await photoProvider.fetchAllPhotos()
            self.allScreenshots = allPhotos.filter { $0.isScreenshot }
            applyFilterAndGroup()
        } catch {
            Logger.error("Failed to load screenshots: \(error)", category: .scan)
        }
        isLoading = false
    }
    
    func setFilter(_ filter: AgeFilter) {
        filterAge = filter
        applyFilterAndGroup()
    }
    
    func toggleSelection(for itemID: String) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }
    
    func toggleGroupSelection(_ group: ScreenshotGroup) {
        let groupIDs = Set(group.items.map(\.id))
        let allSelected = groupIDs.isSubset(of: selectedItemIDs)
        
        if allSelected {
            selectedItemIDs.subtract(groupIDs)
        } else {
            selectedItemIDs.formUnion(groupIDs)
        }
    }
    
    func isGroupSelected(_ group: ScreenshotGroup) -> Bool {
        let groupIDs = Set(group.items.map(\.id))
        return !groupIDs.isEmpty && groupIDs.isSubset(of: selectedItemIDs)
    }
    
    // MARK: - Private Helpers
    
    private func applyFilterAndGroup() {
        let thresholdDate = Calendar.current.date(byAdding: .day, value: -filterAge.days, to: Date()) ?? Date()
        
        let filtered = allScreenshots.filter { item in
            guard let date = item.creationDate else { return false }
            return date < thresholdDate
        }
        
        // Group by month/year (e.g. "August 2023")
        let grouped = Dictionary(grouping: filtered) { item -> String in
            guard let date = item.creationDate else { return "Unknown Date" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        
        // Sort groups (newest month first) and sort items within (newest first)
        self.items = grouped.map { key, items in
            let sortedItems = items.sorted { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
            return ScreenshotGroup(id: key, title: key, items: sortedItems)
        }.sorted { group1, group2 in
            // Parse title back to date for sorting groups, or rely on first item's date
            let date1 = group1.items.first?.creationDate ?? Date.distantPast
            let date2 = group2.items.first?.creationDate ?? Date.distantPast
            return date1 > date2
        }
    }
}

// MARK: - Models

struct ScreenshotGroup: Identifiable {
    let id: String
    let title: String
    let items: [PhotoItem]
}

enum AgeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case oneWeek = "Older than 1 week"
    case oneMonth = "Older than 1 month"
    case threeMonths = "Older than 3 months"
    
    var id: String { rawValue }
    
    var days: Int {
        switch self {
        case .all: return 0
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        }
    }
}
