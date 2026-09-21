import Foundation
import Photos
import Vision
import UIKit

/// Scans photos and groups them by visual similarity using Vision perceptual hashes.
actor SimilarPhotosScanner {
    
    private let photoProvider: PhotoLibraryProviding
    
    // Similarity threshold: lower means more strict.
    // ~10-15 is usually good for "near duplicates" or bursts.
    private let similarityThreshold: Float = 12.0
    
    init(photoProvider: PhotoLibraryProviding) {
        self.photoProvider = photoProvider
    }
    
    /// Scans the provided photos and returns groups of similar ones.
    /// This is an intensive operation that should run in the background.
    func scan(photos: [PhotoItem], progressHandler: @escaping (Double, String) -> Void) async throws -> [PhotoGroup] {
        guard !photos.isEmpty else { return [] }
        
        // Exclude screenshots and items not on device, as they either belong in a different category
        // or can't be hashed quickly.
        let targetPhotos = photos.filter { !$0.isScreenshot && $0.isOnDevice }
        
        let totalCount = targetPhotos.count
        guard totalCount > 1 else { return [] }
        
        var prints: [(PhotoItem, VNFeaturePrintObservation)] = []
        var groups: [PhotoGroup] = []
        
        // 1. Generate feature prints
        progressHandler(0.1, "Generating visual signatures...")
        
        // Process in concurrent batches to avoid memory spikes
        let batchSize = 10
        for stride in stride(from: 0, to: totalCount, by: batchSize) {
            let endIndex = min(stride + batchSize, totalCount)
            let batch = targetPhotos[stride..<endIndex]
            
            // Generate prints concurrently for the batch
            try await withThrowingTaskGroup(of: (PhotoItem, VNFeaturePrintObservation?).self) { group in
                for item in batch {
                    group.addTask {
                        // Load a reasonably sized thumbnail for hashing (doesn't need to be full res)
                        guard let image = await self.photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 300, height: 300)) else {
                            return (item, nil)
                        }
                        do {
                            let print = try await ImageHasher.generateFeaturePrint(for: image)
                            return (item, print)
                        } catch {
                            // Skip failures quietly for individual items
                            return (item, nil)
                        }
                    }
                }
                
                for try await (item, print) in group {
                    if let print = print {
                        prints.append((item, print))
                    }
                }
            }
            
            let progress = 0.1 + (Double(endIndex) / Double(totalCount)) * 0.7
            progressHandler(progress, "Analyzing photo \(endIndex) of \(totalCount)...")
            
            // Yield to avoid blocking
            await Task.yield()
        }
        
        // 2. Compare prints to find groups
        progressHandler(0.85, "Grouping similar photos...")
        
        // Keep track of which items have already been assigned to a group
        var processedIndices = Set<Int>()
        
        for i in 0..<prints.count {
            if processedIndices.contains(i) { continue }
            
            let sourcePrint = prints[i].1
            var currentGroupItems: [PhotoItem] = [prints[i].0]
            processedIndices.insert(i)
            
            for j in (i + 1)..<prints.count {
                if processedIndices.contains(j) { continue }
                
                let targetPrint = prints[j].1
                do {
                    let distance = try ImageHasher.distance(between: sourcePrint, and: targetPrint)
                    
                    if distance < similarityThreshold {
                        currentGroupItems.append(prints[j].0)
                        processedIndices.insert(j)
                    }
                } catch {
                    Logger.error("Comparison failed: \(error)", category: .scan)
                }
            }
            
            // Only create a group if there's more than one item
            if currentGroupItems.count > 1 {
                let bestItemID = self.determineBestItem(in: currentGroupItems)
                let group = PhotoGroup(
                    id: UUID(),
                    items: currentGroupItems,
                    bestItemID: bestItemID
                )
                groups.append(group)
            }
        }
        
        progressHandler(1.0, "Found \(groups.count) groups of similar photos")
        return groups
    }
    
    /// Heuristic to pick the "best" photo in a similar group.
    /// Prefers favorites, then highest resolution/file size, then newest.
    private func determineBestItem(in items: [PhotoItem]) -> String {
        guard let first = items.first else { return "" }
        
        let best = items.max { a, b in
            if a.isFavorite != b.isFavorite {
                return a.isFavorite ? false : true // true means b is greater, so a wins if it's favorite
            }
            
            if a.pixelCount != b.pixelCount {
                return a.pixelCount < b.pixelCount
            }
            
            if a.fileSize != b.fileSize {
                return a.fileSize < b.fileSize
            }
            
            // Fallback to newest
            return (a.creationDate ?? Date.distantPast) < (b.creationDate ?? Date.distantPast)
        }
        
        return best?.id ?? first.id
    }
}
