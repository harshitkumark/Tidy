import Foundation
import Photos
import UIKit

/// Real implementation of PhotoLibraryProviding interacting with PHPhotoLibrary.
final class PhotoService: PhotoLibraryProviding {
    private let imageManager = PHImageManager.default()
    
    // Cache for PHAssets to avoid re-fetching them by ID later
    // In a real production app with 50,000 photos, this might need to be a more memory-efficient map
    // or just fetch by localIdentifier when needed. For this scope, an NSCache or dictionary works.
    private let assetCache = NSCache<NSString, PHAsset>()
    
    func fetchAllPhotos() async throws -> [PhotoItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHFetchOptions()
                // Only get images, not videos or audio
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                // Sort newest first
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let result = PHAsset.fetchAssets(with: options)
                var items: [PhotoItem] = []
                
                // Prefetching could be added here for performance if needed
                
                result.enumerateObjects { asset, _, _ in
                    let item = PhotoItem(
                        id: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        fileSize: self.getFileSize(for: asset),
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        isFavorite: asset.isFavorite,
                        isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                        isInUserAlbum: false, // Would require fetching collections
                        isOnDevice: self.isOnDevice(asset: asset)
                    )
                    items.append(item)
                    self.assetCache.setObject(asset, forKey: asset.localIdentifier as NSString)
                }
                
                continuation.resume(returning: items)
            }
        }
    }
    
    func fetchAllVideos() async throws -> [VideoItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let result = PHAsset.fetchAssets(with: options)
                var items: [VideoItem] = []
                
                result.enumerateObjects { asset, _, _ in
                    let item = VideoItem(
                        id: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        fileSize: self.getFileSize(for: asset),
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        isFavorite: asset.isFavorite,
                        isOnDevice: self.isOnDevice(asset: asset)
                    )
                    items.append(item)
                    self.assetCache.setObject(asset, forKey: asset.localIdentifier as NSString)
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
        // Fetching file size synchronously is tricky and can be slow.
        // We use resource retrieval.
        let resources = PHAssetResource.assetResources(for: asset)
        
        // Find the main resource (photo or video)
        guard let resource = resources.first(where: {
            $0.type == .photo || $0.type == .video || $0.type == .fullSizePhoto || $0.type == .fullSizeVideo
        }) else { return 0 }
        
        // This is a private/undocumented key sometimes used, but `value(forKey: "fileSize")` is safer
        if let size = resource.value(forKey: "fileSize") as? Int64 {
            return size
        }
        return 0
    }
    
    private func isOnDevice(asset: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        // If there's a resource and it's locally available, we assume it's on device.
        // A simple heuristic is that if we can't get file size, it might not be fully on device.
        return resources.contains { $0.value(forKey: "locallyAvailable") as? Bool == true }
    }
}
