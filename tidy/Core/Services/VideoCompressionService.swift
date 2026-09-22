import Foundation
import Photos
import AVFoundation

/// Compresses videos using AVAssetExportSession.
actor VideoCompressionService {
    
    enum CompressionQuality: String, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var id: String { rawValue }
        
        var exportPreset: String {
            switch self {
            case .low: return AVAssetExportPresetMediumQuality
            case .medium: return AVAssetExportPreset1280x720
            case .high: return AVAssetExportPreset1920x1080
            }
        }
        
        var estimatedRatio: Double {
            switch self {
            case .low: return 0.15
            case .medium: return 0.35
            case .high: return 0.6
            }
        }
    }
    
    struct CompressionResult {
        let originalSize: Int64
        let compressedSize: Int64
        let savedBytes: Int64
        let outputURL: URL
    }
    
    /// Compresses a video asset and returns the result.
    /// Progress is reported via the handler (0.0 to 1.0).
    func compress(
        assetIdentifier: String,
        quality: CompressionQuality,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> CompressionResult {
        // 1. Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw CompressionError.assetNotFound
        }
        
        // 2. Get the AVAsset from the PHAsset
        let avAsset = try await loadAVAsset(from: asset)
        
        // 3. Get original file size (estimate from duration)
        let originalSize = estimateSize(for: asset)
        
        // 4. Create export session
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: quality.exportPreset) else {
            throw CompressionError.exportSessionFailed
        }
        
        // 5. Set up output
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 6. Monitor progress
        let progressTask = Task {
            while !Task.isCancelled {
                progressHandler(exportSession.progress)
                try await Task.sleep(for: .milliseconds(200))
            }
        }
        
        // 7. Export
        await exportSession.export()
        progressTask.cancel()
        
        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw CompressionError.exportFailed(error.localizedDescription)
            }
            throw CompressionError.exportFailed("Unknown export error")
        }
        
        // 8. Get compressed size
        let compressedAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let compressedSize = (compressedAttributes[.size] as? Int64) ?? 0
        
        return CompressionResult(
            originalSize: originalSize,
            compressedSize: compressedSize,
            savedBytes: originalSize - compressedSize,
            outputURL: outputURL
        )
    }
    
    /// Saves the compressed video back to the Photo Library and optionally deletes the original.
    func saveCompressedVideo(
        outputURL: URL,
        originalIdentifier: String,
        deleteOriginal: Bool,
        isDryRun: Bool
    ) async throws {
        if isDryRun {
            Logger.info("DRY RUN: Would save compressed video and delete original \(originalIdentifier)", category: .deletion)
            return
        }
        
        // Save to library
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }
        
        // Delete original if requested
        if deleteOriginal {
            let toDelete = PHAsset.fetchAssets(withLocalIdentifiers: [originalIdentifier], options: nil)
            if toDelete.count > 0 {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(toDelete)
                }
            }
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    // MARK: - Helpers
    
    private func loadAVAsset(from phAsset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, _ in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: CompressionError.assetNotFound)
                }
            }
        }
    }
    
    private func estimateSize(for asset: PHAsset) -> Int64 {
        // Estimate based on duration and resolution
        let pixels = Int64(asset.pixelWidth) * Int64(asset.pixelHeight)
        let bitsPerPixel: Double = 8.0 // typical for H.264
        let fps: Double = 30
        let bytesPerSecond = (Double(pixels) * bitsPerPixel * fps) / 8.0
        return Int64(bytesPerSecond * asset.duration)
    }
    
    enum CompressionError: LocalizedError {
        case assetNotFound
        case exportSessionFailed
        case exportFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .assetNotFound: return "Video asset not found."
            case .exportSessionFailed: return "Could not create export session."
            case .exportFailed(let msg): return "Export failed: \(msg)"
            }
        }
    }
}
