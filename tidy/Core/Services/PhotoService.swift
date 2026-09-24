import Foundation
import Photos
import UIKit

/// Real implementation of PhotoLibraryProviding interacting with PHPhotoLibrary.
final class PhotoService: PhotoLibraryProviding {
    private let imageManager = PHCachingImageManager()
    
    // NSCache with limits to prevent runaway memory on large libraries
    private let assetCache: NSCache<NSString, PHAsset> = {
        let cache = NSCache<NSString, PHAsset>()
        cache.countLimit = 500 // Keep at most 500 PHAssets in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB budget
        return cache
    }()
    
    func fetchAllPhotos() async throws -> [PhotoItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let result = PHAsset.fetchAssets(with: options)
                var items: [PhotoItem] = []
                items.reserveCapacity(result.count) // Pre-allocate to avoid reallocs
                
                // Wrap in autoreleasepool to release intermediate ObjC objects each iteration
                result.enumerateObjects { asset, _, _ in
                    autoreleasepool {
                        let item = PhotoItem(
                            id: asset.localIdentifier,
                            creationDate: asset.creationDate,
                            fileSize: self.getFileSize(for: asset),
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            isFavorite: asset.isFavorite,
                            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                            isInUserAlbum: false,
                            isOnDevice: true
                        )
                        items.append(item)
                    }
                }
                
                continuation.resume(returning: items)
            }
        }
    }
    
    func fetchAllVideos() async throws -> [VideoItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let result = PHAsset.fetchAssets(with: options)
                var items: [VideoItem] = []
                items.reserveCapacity(result.count)
                
                result.enumerateObjects { asset, _, _ in
                    autoreleasepool {
                        let item = VideoItem(
                            id: asset.localIdentifier,
                            creationDate: asset.creationDate,
                            fileSize: self.getVideoFileSize(for: asset),
                            duration: asset.duration,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            isFavorite: asset.isFavorite,
                            isOnDevice: true
                        )
                        items.append(item)
                    }
                }
                
                continuation.resume(returning: items)
            }
        }
    }
    
    func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = getAsset(for: localIdentifier) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat // Only calls back once
            options.resizeMode = .fast
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    func loadFullImage(for localIdentifier: String) async -> UIImage? {
        guard let asset = getAsset(for: localIdentifier) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true // Allow downloading from iCloud if needed
            options.deliveryMode = .highQualityFormat
            
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    func authorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    
    func visibleAssetCount() async -> Int {
        let options = PHFetchOptions()
        return PHAsset.fetchAssets(with: options).count
    }
    
    // MARK: - Helpers
    
    private func getAsset(for localIdentifier: String) -> PHAsset? {
        if let cached = assetCache.object(forKey: localIdentifier as NSString) {
            return cached
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return result.firstObject
    }
    
    private func getFileSize(for asset: PHAsset) -> Int64 {
        // PHAssetResource.assetResources(for:) is incredibly slow and can hang the simulator or block threads for minutes.
        // Instead, we estimate the file size based on resolution. 
        // 12MP photo (4032x3024) = 12,192,768 pixels. Usually ~3-4MB in HEIC.
        // So roughly bytes = pixels / 3.
        let pixels = Int64(asset.pixelWidth) * Int64(asset.pixelHeight)
        if pixels > 0 {
            return pixels / 3
        }
        return 0
    }
    
    private func getVideoFileSize(for asset: PHAsset) -> Int64 {
        // For videos we use PHAssetResource since video count is small (usually <100)
        // and the pixel heuristic doesn't work for videos at all.
        let resources = PHAssetResource.assetResources(for: asset)
        if let videoResource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) {
            if let size = videoResource.value(forKey: "fileSize") as? Int64, size > 0 {
                return size
            }
        }
        // Fallback: estimate from duration and resolution
        // Typical iPhone video: ~10 Mbps bitrate
        let estimatedBitrate: Double = 10_000_000 // 10 Mbps
        return Int64((estimatedBitrate * asset.duration) / 8.0)
    }
    
    private func isOnDevice(asset: PHAsset) -> Bool {
        // Assume true for now to avoid slow PHAssetResource fetches
        return true
    }
}
