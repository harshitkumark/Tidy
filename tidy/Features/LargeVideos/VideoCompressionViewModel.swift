import SwiftUI

@MainActor
@Observable
final class VideoCompressionViewModel {
    // MARK: - State
    var videos: [VideoItem] = []
    var selectedVideoID: String?
    var selectedQuality: VideoCompressionService.CompressionQuality = .medium
    
    var isCompressing = false
    var progress: Float = 0
    var errorMsg: String?
    var successMsg: String?
    var savedBytes: Int64 = 0
    
    private let photoProvider: PhotoLibraryProviding
    private let compressionService = VideoCompressionService()
    
    init(photoProvider: PhotoLibraryProviding = PhotoService()) {
        self.photoProvider = photoProvider
    }
    
    // MARK: - Intents
    
    func load() async {
        do {
            // Sort videos by size descending
            let allVideos = try await photoProvider.fetchAllVideos()
            self.videos = allVideos.sorted { $0.fileSize > $1.fileSize }
            if selectedVideoID == nil {
                selectedVideoID = self.videos.first?.id
            }
        } catch {
            errorMsg = "Failed to load videos: \(error.localizedDescription)"
        }
    }
    
    func compressSelected(isDryRun: Bool) async {
        guard let id = selectedVideoID else { return }
        isCompressing = true
        progress = 0
        errorMsg = nil
        successMsg = nil
        
        do {
            let result = try await compressionService.compress(
                assetIdentifier: id,
                quality: selectedQuality
            ) { [weak self] currentProgress in
                Task { @MainActor in
                    self?.progress = currentProgress
                }
            }
            
            try await compressionService.saveCompressedVideo(
                outputURL: result.outputURL,
                originalIdentifier: id,
                deleteOriginal: true,
                isDryRun: isDryRun
            )
            
            savedBytes += result.savedBytes
            
            if isDryRun {
                successMsg = "DRY RUN: Would have saved \(ByteFormatter.formatShort(result.savedBytes))"
            } else {
                successMsg = "Success! You saved \(ByteFormatter.formatShort(result.savedBytes))"
                // Remove from list since we replaced it
                videos.removeAll { $0.id == id }
                selectedVideoID = videos.first?.id
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        
        isCompressing = false
    }
}
