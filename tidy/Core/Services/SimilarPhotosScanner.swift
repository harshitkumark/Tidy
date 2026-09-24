import Foundation
import Photos
import Vision
import UIKit

/// Scans photos and groups them by visual similarity.
/// Uses Vision perceptual hashes on real devices, falls back to pixel-based
/// average hashing (aHash) when Vision is unavailable (e.g., Simulator).
actor SimilarPhotosScanner {
    
    private let photoProvider: PhotoLibraryProviding
    
    // Vision similarity threshold: lower means more strict.
    // ~10-15 is usually good for "near duplicates" or bursts.
    private let visionThreshold: Float = 12.0
    
    // aHash Hamming distance threshold: < 5 bits different = very similar
    private let hashThreshold: Int = 5
    
    init(photoProvider: PhotoLibraryProviding) {
        self.photoProvider = photoProvider
    }
    
    /// Scans the provided photos and returns groups of similar ones.
    /// This is an intensive operation that should run in the background.
    func scan(photos: [PhotoItem], progressHandler: @escaping (Double, String) -> Void) async throws -> [PhotoGroup] {
        guard !photos.isEmpty else { return [] }
        
        // Exclude screenshots and items not on device
        var targetPhotos = photos.filter { !$0.isScreenshot && $0.isOnDevice }
        
        // Cap at 500 photos to prevent excessive memory usage and scan time
        if targetPhotos.count > 500 {
            targetPhotos = Array(targetPhotos.prefix(500))
            Logger.info("Capping similar photos scan at 500 items (library has \(photos.count))", category: .scan)
        }
        
        let totalCount = targetPhotos.count
        guard totalCount > 1 else { return [] }
        
        // Try Vision first, fall back to aHash if it fails
        progressHandler(0.1, "Generating visual signatures...")
        
        let visionResult = await tryVisionScan(photos: targetPhotos, totalCount: totalCount, progressHandler: progressHandler)
        
        if !visionResult.isEmpty {
            Logger.info("Vision scan succeeded: \(visionResult.count) groups found", category: .scan)
            progressHandler(1.0, "Found \(visionResult.count) groups of similar photos")
            return visionResult
        }
        
        // Vision failed — fall back to pixel hash
        Logger.info("Vision unavailable, falling back to pixel-based hash comparison", category: .scan)
        progressHandler(0.3, "Using pixel analysis (Vision unavailable)...")
        
        let hashResult = await hashBasedScan(photos: targetPhotos, totalCount: totalCount, progressHandler: progressHandler)
        
        progressHandler(1.0, "Found \(hashResult.count) groups of similar photos")
        return hashResult
    }
    
    // MARK: - Vision-based Scan
    
    private func tryVisionScan(photos: [PhotoItem], totalCount: Int, progressHandler: @escaping (Double, String) -> Void) async -> [PhotoGroup] {
        var prints: [(PhotoItem, VNFeaturePrintObservation)] = []
        var visionFailed = false
        
        let batchSize = 10
        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            if Task.isCancelled { return [] }
            
            let endIndex = min(batchStart + batchSize, totalCount)
            let batch = photos[batchStart..<endIndex]
            
            var batchSuccess = 0
            var batchFail = 0
            
            do {
                try await withThrowingTaskGroup(of: (PhotoItem, VNFeaturePrintObservation?).self) { group in
                    for item in batch {
                        group.addTask {
                            guard let image = await self.photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 300, height: 300)) else {
                                return (item, nil)
                            }
                            do {
                                let featurePrint = try await ImageHasher.generateFeaturePrint(for: image)
                                return (item, featurePrint)
                            } catch {
                                return (item, nil)
                            }
                        }
                    }
                    
                    for try await (item, featurePrint) in group {
                        if let featurePrint {
                            prints.append((item, featurePrint))
                            batchSuccess += 1
                        } else {
                            batchFail += 1
                        }
                    }
                }
            } catch {
                Logger.error("Vision batch failed: \(error)", category: .scan)
            }
            
            Logger.info("Vision batch: \(batchSuccess) ok, \(batchFail) failed", category: .scan)
            
            // If the first batch completely failed, Vision is broken — abort early
            if batchStart == 0 && batchSuccess == 0 && batchFail > 0 {
                Logger.warning("Vision completely failed on first batch — switching to fallback", category: .scan)
                visionFailed = true
                break
            }
            
            let progress = 0.1 + (Double(endIndex) / Double(totalCount)) * 0.7
            progressHandler(progress, "Analyzing photo \(endIndex) of \(totalCount)...")
            
            await Task.yield()
        }
        
        if visionFailed || prints.isEmpty {
            return []
        }
        
        // Compare prints to find groups
        progressHandler(0.85, "Grouping similar photos...")
        return groupByVision(prints: prints)
    }
    
    private func groupByVision(prints: [(PhotoItem, VNFeaturePrintObservation)]) -> [PhotoGroup] {
        var groups: [PhotoGroup] = []
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
                    if distance < visionThreshold {
                        currentGroupItems.append(prints[j].0)
                        processedIndices.insert(j)
                    }
                } catch {
                    Logger.error("Comparison failed: \(error)", category: .scan)
                }
            }
            
            if currentGroupItems.count > 1 {
                let bestItemID = determineBestItem(in: currentGroupItems)
                groups.append(PhotoGroup(id: UUID(), items: currentGroupItems, bestItemID: bestItemID))
            }
        }
        
        return groups
    }
    
    // MARK: - Pixel Hash Fallback
    
    private func hashBasedScan(photos: [PhotoItem], totalCount: Int, progressHandler: @escaping (Double, String) -> Void) async -> [PhotoGroup] {
        var hashes: [(PhotoItem, UInt64)] = []
        
        let batchSize = 10
        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            if Task.isCancelled { return [] }
            
            let endIndex = min(batchStart + batchSize, totalCount)
            let batch = photos[batchStart..<endIndex]
            
            // Generate hashes for the batch
            for item in batch {
                guard let image = await photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 300, height: 300)) else {
                    continue
                }
                if let hash = ImageHasher.generateAverageHash(for: image) {
                    hashes.append((item, hash))
                }
            }
            
            let progress = 0.3 + (Double(endIndex) / Double(totalCount)) * 0.6
            progressHandler(progress, "Hashing photo \(endIndex) of \(totalCount)...")
            
            await Task.yield()
        }
        
        // Compare hashes to find groups
        progressHandler(0.92, "Grouping similar photos...")
        
        var groups: [PhotoGroup] = []
        var processedIndices = Set<Int>()
        
        for i in 0..<hashes.count {
            if processedIndices.contains(i) { continue }
            
            let sourceHash = hashes[i].1
            var currentGroupItems: [PhotoItem] = [hashes[i].0]
            processedIndices.insert(i)
            
            for j in (i + 1)..<hashes.count {
                if processedIndices.contains(j) { continue }
                
                let distance = ImageHasher.hammingDistance(sourceHash, hashes[j].1)
                if distance <= hashThreshold {
                    currentGroupItems.append(hashes[j].0)
                    processedIndices.insert(j)
                }
            }
            
            if currentGroupItems.count > 1 {
                let bestItemID = determineBestItem(in: currentGroupItems)
                groups.append(PhotoGroup(id: UUID(), items: currentGroupItems, bestItemID: bestItemID))
            }
        }
        
        Logger.info("Hash scan complete: \(hashes.count) hashes, \(groups.count) groups", category: .scan)
        return groups
    }
    
    // MARK: - Best Item Selection
    
    /// Heuristic to pick the "best" photo in a similar group.
    /// Prefers favorites, then highest resolution/file size, then newest.
    private func determineBestItem(in items: [PhotoItem]) -> String {
        guard let first = items.first else { return "" }
        
        let best = items.max { a, b in
            if a.isFavorite != b.isFavorite {
                return a.isFavorite ? false : true
            }
            
            if a.pixelCount != b.pixelCount {
                return a.pixelCount < b.pixelCount
            }
            
            if a.fileSize != b.fileSize {
                return a.fileSize < b.fileSize
            }
            
            return (a.creationDate ?? Date.distantPast) < (b.creationDate ?? Date.distantPast)
        }
        
        return best?.id ?? first.id
    }
}
