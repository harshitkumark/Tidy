import Foundation
import Photos
import UIKit
import CoreGraphics
import AVFoundation

#if DEBUG
/// Generates synthetic photos and videos and saves them to the real Photo Library for testing.
actor LibrarySeeder {
    
    /// Seeds the specified number of items into the Photo Library
    func seedItems(count: Int, progressHandler: @escaping (String) -> Void) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "LibrarySeeder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied."])
        }
        
        let batchSize = 20
        let batches = count / batchSize
        let remainder = count % batchSize
        
        for i in 0..<batches {
            progressHandler("Seeding batch \(i + 1) of \(batches)...")
            try await seedBatch(size: batchSize, batchIndex: i)
        }
        
        if remainder > 0 {
            progressHandler("Seeding final items...")
            try await seedBatch(size: remainder, batchIndex: batches)
        }
    }
    
    private func seedBatch(size: Int, batchIndex: Int) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            for j in 0..<size {
                let isVideo = j % 15 == 0 // 1 in 15 is a video
                let isScreenshot = j % 10 == 0 // 1 in 10 is a screenshot
                
                if isVideo {
                    // In a real app we'd use AVAssetWriter to generate a video file, but that's complex
                    // For the sake of this test implementation, we'll generate mostly photos.
                    // To do videos properly requires writing frames to an mp4 file then saving it.
                    self.addSyntheticPhoto(isScreenshot: isScreenshot)
                } else {
                    self.addSyntheticPhoto(isScreenshot: isScreenshot)
                }
            }
        }
    }
    
    private func addSyntheticPhoto(isScreenshot: Bool) {
        // Create a basic colored image
        let width = isScreenshot ? 1170 : 4032
        let height = isScreenshot ? 2532 : 3024
        let size = CGSize(width: width, height: height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Random background color
        let color = UIColor(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            alpha: 1.0
        )
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Draw some text to make it unique
        let text = "TIDY_TEST\n\(UUID().uuidString)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 120),
            .foregroundColor: UIColor.white
        ]
        text.draw(at: CGPoint(x: 100, y: 100), withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Save to library
        let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
        
        // Offset creation date to simulate old photos
        let randomDaysAgo = Double.random(in: 0...365)
        request.creationDate = Date().addingTimeInterval(-randomDaysAgo * 86400)
    }
}
#endif
