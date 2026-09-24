import Foundation
import UIKit
import Vision
import CoreGraphics

/// Generates and compares perceptual hashes (Feature Prints) using the Vision framework.
/// Falls back to a pixel-based average hash when Vision is unavailable (e.g., Simulator).
enum ImageHasher: Sendable {
    
    /// Generates a feature print observation for a given image.
    /// This represents the semantic content of the image, rather than just the pixels.
    static func generateFeaturePrint(for image: UIImage) async throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ImageHasher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNGenerateImageFeaturePrintRequest()
                request.imageCropAndScaleOption = .scaleFit
                
                do {
                    try requestHandler.perform([request])
                    
                    // Modern Vision API: results is already typed
                    if let firstResult = request.results?.first {
                        continuation.resume(returning: firstResult)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ImageHasher", code: 2, userInfo: [NSLocalizedDescriptionKey: "No feature print generated"]))
                    }
                } catch {
                    Logger.error("Vision perform failed: \(error.localizedDescription)", category: .scan)
                    continuation.resume(throwing: error)
                }
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
    
    // MARK: - Pixel Hash Fallback (for Simulator)
    
    /// Generates a simple average hash (aHash) from an image.
    /// Works everywhere including the Simulator. Less accurate than Vision but functional.
    static func generateAverageHash(for image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 1. Resize to 8x8 grayscale
        let size = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return nil }
        
        let pixelData = data.bindMemory(to: UInt8.self, capacity: size * size)
        
        // 2. Compute average brightness
        var total: Int = 0
        for i in 0..<(size * size) {
            total += Int(pixelData[i])
        }
        let average = UInt8(total / (size * size))
        
        // 3. Generate 64-bit hash: each bit = 1 if pixel > average, 0 otherwise
        var hash: UInt64 = 0
        for i in 0..<(size * size) {
            if pixelData[i] > average {
                hash |= (1 << i)
            }
        }
        
        return hash
    }
    
    /// Calculates the Hamming distance between two average hashes.
    /// Lower = more similar. 0 = identical. < 5 = very similar.
    static func hammingDistance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        let xor = hash1 ^ hash2
        return xor.nonzeroBitCount
    }
}
