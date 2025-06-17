// CardCropper.swift
import Vision
import UIKit
import CoreImage

class CardCropper {
    static let shared = CardCropper()
    
    // Detect and crop card from image
    func detectAndCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                print("Rectangle detection error: \(error)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation],
                  let bestRectangle = self.findBestCardRectangle(observations) else {
                // If no good rectangle found, return original image
                completion(image)
                return
            }
            
            // Crop the image using the detected rectangle
            let croppedImage = self.cropImage(cgImage, to: bestRectangle)
            completion(croppedImage)
        }
        
        // Configure the request for better card detection
        request.minimumAspectRatio = 0.5  // Cards are roughly rectangular
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1         // Minimum size relative to image
        request.minimumConfidence = 0.6   // Higher confidence for better results
        request.maximumObservations = 5   // Look at top 5 rectangles
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform rectangle detection: \(error)")
            completion(nil)
        }
    }
    
    // Find the best rectangle that looks like a card
    private func findBestCardRectangle(_ observations: [VNRectangleObservation]) -> VNRectangleObservation? {
        // Filter rectangles by card-like properties
        let cardCandidates = observations.filter { rectangle in
            let aspectRatio = rectangle.boundingBox.width / rectangle.boundingBox.height
            let area = rectangle.boundingBox.width * rectangle.boundingBox.height
            
            // Standard trading card aspect ratio is approximately 2.5:3.5 (0.714)
            // Allow some variance: 0.6 to 0.8
            let isCardAspectRatio = aspectRatio >= 0.6 && aspectRatio <= 0.8
            
            // Card should take up a reasonable portion of the image
            let isReasonableSize = area >= 0.1 && area <= 0.9
            
            // High confidence in detection
            let isHighConfidence = rectangle.confidence >= 0.7
            
            return isCardAspectRatio && isReasonableSize && isHighConfidence
        }
        
        // Sort by confidence and size, prefer larger, more confident rectangles
        return cardCandidates.max { rect1, rect2 in
            let score1 = rect1.confidence * Float(rect1.boundingBox.width * rect1.boundingBox.height)
            let score2 = rect2.confidence * Float(rect2.boundingBox.width * rect2.boundingBox.height)
            return score1 < score2
        }
    }
    
    // Crop image to the detected rectangle with perspective correction
    private func cropImage(_ cgImage: CGImage, to rectangle: VNRectangleObservation) -> UIImage? {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Convert normalized coordinates to image coordinates
        let topLeft = CGPoint(
            x: rectangle.topLeft.x * imageSize.width,
            y: (1 - rectangle.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: rectangle.topRight.x * imageSize.width,
            y: (1 - rectangle.topRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: rectangle.bottomLeft.x * imageSize.width,
            y: (1 - rectangle.bottomLeft.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: rectangle.bottomRight.x * imageSize.width,
            y: (1 - rectangle.bottomRight.y) * imageSize.height
        )
        
        // Create perspective correction
        let ciImage = CIImage(cgImage: cgImage)
        
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveCorrection.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputImage = perspectiveCorrection.outputImage else {
            return nil
        }
        
        // Convert back to UIImage
        let context = CIContext()
        guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: correctedCGImage)
    }
    
    // Alternative: Simple bounding box crop without perspective correction
    func simpleCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let observations = request.results as? [VNRectangleObservation],
                  let bestRectangle = self.findBestCardRectangle(observations) else {
                completion(image)
                return
            }
            
            // Simple crop using bounding box
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let cropRect = CGRect(
                x: bestRectangle.boundingBox.origin.x * imageSize.width,
                y: (1 - bestRectangle.boundingBox.origin.y - bestRectangle.boundingBox.height) * imageSize.height,
                width: bestRectangle.boundingBox.width * imageSize.width,
                height: bestRectangle.boundingBox.height * imageSize.height
            )
            
            guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
                completion(image)
                return
            }
            
            completion(UIImage(cgImage: croppedCGImage))
        }
        
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.minimumConfidence = 0.6
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }
    
    // Enhanced detection with edge enhancement
    func detectCardWithEdgeEnhancement(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        // Apply edge enhancement to improve rectangle detection
        let ciImage = CIImage(cgImage: cgImage)
        
        // Edge enhancement filter
        let edgeFilter = CIFilter(name: "CIEdges")!
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let edgeImage = edgeFilter.outputImage else {
            completion(nil)
            return
        }
        
        let context = CIContext()
        guard let enhancedCGImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            completion(nil)
            return
        }
        
        // Perform rectangle detection on edge-enhanced image
        let request = VNDetectRectanglesRequest { request, error in
            guard let observations = request.results as? [VNRectangleObservation],
                  let bestRectangle = self.findBestCardRectangle(observations) else {
                completion(image)
                return
            }
            
            // Crop the original image (not the edge-enhanced one)
            let croppedImage = self.cropImage(cgImage, to: bestRectangle)
            completion(croppedImage)
        }
        
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.minimumConfidence = 0.5
        
        let handler = VNImageRequestHandler(cgImage: enhancedCGImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }
}
