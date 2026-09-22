import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Scans photos to detect blurry ones using CoreImage edge detection and variance.
actor BlurryPhotosScanner {
    
    private let photoProvider: PhotoLibraryProviding
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    
    // Lower threshold means stricter (fewer photos flagged as blurry).
    // Higher threshold means looser (more photos flagged).
    private let varianceThreshold: Double = 5.0
    
    init(photoProvider: PhotoLibraryProviding) {
        self.photoProvider = photoProvider
    }
    
    /// Scans the provided photos and returns those deemed blurry.
    func scan(photos: [PhotoItem], progressHandler: @escaping (Double, String) -> Void) async throws -> [PhotoItem] {
        guard !photos.isEmpty else { return [] }
        
        var targetPhotos = photos.filter { !$0.isScreenshot && $0.isOnDevice }
        
        if targetPhotos.count > 1000 {
            targetPhotos = Array(targetPhotos.prefix(1000))
            Logger.info("Capping blurry photos scan at 1000 items", category: .scan)
        }
        
        let totalCount = targetPhotos.count
        guard totalCount > 0 else { return [] }
        
        var blurryPhotos: [PhotoItem] = []
        
        progressHandler(0.1, "Analyzing photo sharpness...")
        
        let batchSize = 10
        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            try Task.checkCancellation()
            
            let endIndex = min(batchStart + batchSize, totalCount)
            let batch = targetPhotos[batchStart..<endIndex]
            
            try await withThrowingTaskGroup(of: (PhotoItem, Bool).self) { group in
                for item in batch {
                    group.addTask {
                        // We need a decent size to detect edges, but not full res
                        guard let image = await self.photoProvider.loadThumbnail(for: item.id, targetSize: CGSize(width: 500, height: 500)),
                              let cgImage = image.cgImage else {
                            return (item, false)
                        }
                        
                        let isBlurry = await withCheckedContinuation { continuation in
                            DispatchQueue.global(qos: .userInitiated).async {
                                let blurry = self.calculateBlurriness(cgImage: cgImage)
                                continuation.resume(returning: blurry)
                            }
                        }
                        
                        return (item, isBlurry)
                    }
                }
                
                for try await (item, isBlurry) in group {
                    if isBlurry {
                        blurryPhotos.append(item)
                    }
                }
            }
            
            let progress = 0.1 + (Double(endIndex) / Double(totalCount)) * 0.9
            progressHandler(progress, "Analyzing photo \(endIndex) of \(totalCount)...")
            
            await Task.yield()
        }
        
        progressHandler(1.0, "Found \(blurryPhotos.count) blurry photos")
        return blurryPhotos
    }
    
    /// Calculates if an image is blurry.
    /// It applies a CILineOverlay (edge detection) and then calculates the variance of the result.
    /// If variance is low, the image lacks sharp edges and is likely blurry.
    nonisolated private func calculateBlurriness(cgImage: CGImage) -> Bool {
        let ciImage = CIImage(cgImage: cgImage)
        
        // 1. Detect edges (high-pass filter)
        let edgesFilter = CIFilter.edges()
        edgesFilter.inputImage = ciImage
        edgesFilter.intensity = 1.0
        guard let outputImage = edgesFilter.outputImage else { return false }
        
        // 2. Calculate variance of the edges
        let areaAverageFilter = CIFilter.areaAverage()
        areaAverageFilter.inputImage = outputImage
        areaAverageFilter.extent = outputImage.extent
        
        guard let averageOutput = areaAverageFilter.outputImage else { return false }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(averageOutput, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Convert RGBA to grayscale average
        let averageIntensity = (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / 3.0
        
        // If the average edge intensity is very low, there are no sharp edges
        return averageIntensity < varianceThreshold
    }
}
