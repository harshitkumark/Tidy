import Foundation
import Photos

/// Protocol for photo library access. Enables mocking in Test Mode and unit tests.
protocol PhotoLibraryProviding: Sendable {
    /// Fetch lightweight metadata for all photo assets
    func fetchAllPhotos() async throws -> [PhotoItem]
    /// Fetch lightweight metadata for all video assets
    func fetchAllVideos() async throws -> [VideoItem]
    /// Load a thumbnail image for the given asset identifier
    func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage?
    /// Load a full-size image for preview
    func loadFullImage(for localIdentifier: String) async -> UIImage?
    /// Get the current photo library authorization status
    func authorizationStatus() -> PHAuthorizationStatus
    /// Request photo library authorization
    func requestAuthorization() async -> PHAuthorizationStatus
    /// Count of assets visible to the app (relevant for limited access)
    func visibleAssetCount() async -> Int
}
