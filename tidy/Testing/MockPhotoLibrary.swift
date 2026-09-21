import Foundation
import Photos
import UIKit

/// A mock photo library for SwiftUI previews and Test Mode dry-runs.
/// Returns a fixed set of synthetic PhotoItem and VideoItem data.
struct MockPhotoLibrary: PhotoLibraryProviding {
    let mockPhotos: [PhotoItem]
    let mockVideos: [VideoItem]
    let authorization: PHAuthorizationStatus

    init(count: Int = 120, status: PHAuthorizationStatus = .authorized) {
        self.authorization = status
        
        // Generate some fake photos
        var photos: [PhotoItem] = []
        let now = Date()
        for i in 0..<count {
            let isScreenshot = i % 10 == 0
            let isFavorite = i % 25 == 0
            
            photos.append(PhotoItem(
                id: "mock_photo_\(i)",
                creationDate: now.addingTimeInterval(-Double(i) * 86400.0), // spread over days
                fileSize: Int64.random(in: 500_000...5_000_000), // 500KB to 5MB
                pixelWidth: isScreenshot ? 1170 : 4032,
                pixelHeight: isScreenshot ? 2532 : 3024,
                isFavorite: isFavorite,
                isScreenshot: isScreenshot,
                isInUserAlbum: false,
                isOnDevice: true
            ))
        }
        self.mockPhotos = photos
        
        // Generate some fake videos
        var videos: [VideoItem] = []
        for i in 0..<(count / 10) {
            videos.append(VideoItem(
                id: "mock_video_\(i)",
                creationDate: now.addingTimeInterval(-Double(i) * 86400.0 * 2),
                fileSize: Int64.random(in: 50_000_000...1_500_000_000), // 50MB to 1.5GB
                duration: TimeInterval.random(in: 15...3600), // 15s to 1h
                pixelWidth: 1920,
                pixelHeight: 1080,
                isFavorite: i == 0,
                isOnDevice: true
            ))
        }
        self.mockVideos = videos
    }
    
    func fetchAllPhotos() async throws -> [PhotoItem] {
        try await Task.sleep(for: .milliseconds(300)) // simulate fetch
        return mockPhotos
    }
    
    func fetchAllVideos() async throws -> [VideoItem] {
        try await Task.sleep(for: .milliseconds(100))
        return mockVideos
    }
    
    func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        // Return a solid color placeholder for thumbnails
        let rect = CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let color = UIColor(hue: CGFloat(abs(localIdentifier.hashValue) % 256) / 256.0, saturation: 0.5, brightness: 0.8, alpha: 1.0)
        color.setFill()
        UIBezierPath(rect: rect).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func loadFullImage(for localIdentifier: String) async -> UIImage? {
        return await loadThumbnail(for: localIdentifier, targetSize: CGSize(width: 1000, height: 1000))
    }
    
    func authorizationStatus() -> PHAuthorizationStatus {
        return authorization
    }
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        return authorization
    }
    
    func visibleAssetCount() async -> Int {
        return mockPhotos.count + mockVideos.count
    }
}
