import SwiftUI

@MainActor
@Observable
final class SimilarPhotosViewModel {
    // MARK: - State
    var groups: [PhotoGroup] = []
    
    // IDs of photos the user has explicitly selected for deletion
    var selectedItemIDs: Set<String> = []
    
    var isLoading = true
    var progress: Double = 0
    var statusText: String = "Preparing scan..."
    
    // Output stats
    var selectedCount: Int { selectedItemIDs.count }
    var selectedSize: Int64 {
        let allItems = groups.flatMap(\.items)
        return allItems.filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let photoProvider: PhotoLibraryProviding
    private var hasScanned = false
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        self.photoProvider = photoProvider
    }
    
    // MARK: - Intents
    
    func startScanIfNeeded() async {
        guard !hasScanned else { return }
        isLoading = true
        
        do {
            let allPhotos = try await photoProvider.fetchAllPhotos()
            
            // Hand off to scanner actor
            let scanner = SimilarPhotosScanner(photoProvider: photoProvider)
            
            let foundGroups = try await scanner.scan(photos: allPhotos) { [weak self] progress, status in
                Task { @MainActor in
                    self?.progress = progress
                    self?.statusText = status
                }
            }
            
            self.groups = foundGroups
            
            // By default, select all items EXCEPT the "best" item in each group
            var defaultSelection: Set<String> = []
            for group in foundGroups {
                let duplicates = group.items.filter { $0.id != group.bestItemID }
                defaultSelection.formUnion(duplicates.map(\.id))
            }
            self.selectedItemIDs = defaultSelection
            self.hasScanned = true
            
        } catch {
            Logger.error("Failed to scan similar photos: \(error)", category: .scan)
            self.statusText = "Scan failed."
        }
        
        isLoading = false
    }
    
    func toggleSelection(for itemID: String) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }
    
    func keepBest(in group: PhotoGroup) {
        let otherIDs = Set(group.items.filter { $0.id != group.bestItemID }.map(\.id))
        selectedItemIDs.formUnion(otherIDs)
        selectedItemIDs.remove(group.bestItemID)
    }
    
    func keepAll(in group: PhotoGroup) {
        let allIDs = Set(group.items.map(\.id))
        selectedItemIDs.subtract(allIDs)
    }
}
