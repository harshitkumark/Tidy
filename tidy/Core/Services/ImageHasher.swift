import Foundation
import UIKit
import Vision

/// Generates and compares perceptual hashes (Feature Prints) using the Vision framework.
enum ImageHasher: Sendable {
    
    /// Generates a feature print observation for a given image.
    /// This represents the semantic content of the image, rather than just the pixels.
    static func generateFeaturePrint(for image: UIImage) async throws -> VNFeaturePrintObservation {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: NSError(domain: "ImageHasher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"]))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNFeaturePrintObservation],
                      let firstResult = results.first else {
                    continuation.resume(throwing: NSError(domain: "ImageHasher", code: 2, userInfo: [NSLocalizedDescriptionKey: "No feature print generated"]))
                    return
                }
                
                continuation.resume(returning: firstResult)
            }
            
            // Prefer speed and lower memory usage since we're just checking for similarity
            request.imageCropAndScaleOption = .scaleFit
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Calculates the perceptual distance between two feature prints.
    /// Lower distance means higher similarity.
    /// - Returns: A Float representing the distance. Typically < 10 is very similar.
    static func distance(between print1: VNFeaturePrintObservation, and print2: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try print1.computeDistance(&distance, to: print2)
        return distance
    }
}
