import SwiftUI

@MainActor
@Observable
final class BlurryPhotosViewModel {
    // MARK: - State
    var items: [PhotoItem] = []
    var selectedItemIDs: Set<String> = []
    
    var isLoading = true
    var progress: Double = 0
    var statusText: String = "Preparing scan..."
    
    // Output stats
    var selectedCount: Int { selectedItemIDs.count }
    var selectedSize: Int64 {
        items.filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let photoProvider: PhotoLibraryProviding
    private var hasScanned = false
    private var scanTask: Task<Void, Never>?
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        self.photoProvider = photoProvider
    }
    
    // MARK: - Intents
    
    func load() {
        guard !hasScanned else { return }
        hasScanned = true
        isLoading = true
        progress = 0
        
        scanTask = Task {
            do {
                let allPhotos = try await photoProvider.fetchAllPhotos()
                let scanner = BlurryPhotosScanner(photoProvider: photoProvider)
                
                let blurryPhotos = try await scanner.scan(photos: allPhotos) { [weak self] currentProgress, text in
                    Task { @MainActor in
                        self?.progress = currentProgress
                        self?.statusText = text
                    }
                }
                
                if !Task.isCancelled {
                    self.items = blurryPhotos
                    // Auto-select all blurry photos by default
                    self.selectedItemIDs = Set(blurryPhotos.map(\.id))
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    Logger.error("Blurry photo scan failed: \(error)", category: .scan)
                    self.items = []
                    self.isLoading = false
                }
            }
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
    }
    
    func toggleSelection(for id: String) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
}
