import Vision
import UIKit
import CoreImage

class CardCropper {
	static let shared = CardCropper()
	
	// Detect and crop card from image with enhanced parameters
	func detectAndCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
		guard let cgImage = image.cgImage else {
			print("❌ CardCropper: Failed to get CGImage")
			completion(nil)
			return
		}
		
		print("🔍 CardCropper: Starting detection on image size: \(cgImage.width)x\(cgImage.height)")
		print("🔍 CardCropper: Original UIImage orientation: \(image.imageOrientation.rawValue)")
		
		let request = VNDetectRectanglesRequest { request, error in
			if let error = error {
				print("❌ CardCropper: Rectangle detection error: \(error)")
				completion(image) // Return original on error
				return
			}
			
			guard let observations = request.results as? [VNRectangleObservation] else {
				print("❌ CardCropper: No rectangle observations found")
				completion(image) // Return original if no rectangles
				return
			}
			
			print("✅ CardCropper: Found \(observations.count) rectangles")
			
			// Log all rectangles for debugging
			for (index, rect) in observations.enumerated() {
				let aspectRatio = rect.boundingBox.width / rect.boundingBox.height
				let area = rect.boundingBox.width * rect.boundingBox.height
				print("   Rectangle \(index): confidence=\(rect.confidence), aspect=\(aspectRatio), area=\(area)")
			}
			
			guard let bestRectangle = self.findBestCardRectangle(observations) else {
				print("❌ CardCropper: No suitable card rectangle found, using original image")
				completion(image)
				return
			}
			
			print("✅ CardCropper: Selected rectangle with confidence: \(bestRectangle.confidence)")
			
			// Try cropping the image with proper orientation
			let croppedImage = self.cropImageWithCorrectOrientation(image, to: bestRectangle)
			if croppedImage != nil {
				print("✅ CardCropper: Successfully cropped image with correct orientation")
			} else {
				print("❌ CardCropper: Failed to crop image, using original")
			}
			completion(croppedImage ?? image)
		}
		
		// More lenient parameters for better detection
		request.minimumAspectRatio = 0.4    // More lenient (was 0.5)
		request.maximumAspectRatio = 2.5    // More lenient (was 2.0)
		request.minimumSize = 0.05          // Smaller minimum (was 0.1)
		request.minimumConfidence = 0.3     // Lower confidence threshold (was 0.6)
		request.maximumObservations = 10    // More candidates (was 5)
		
		let handler = VNImageRequestHandler(cgImage: cgImage, orientation: self.cgImageOrientation(from: image.imageOrientation), options: [:])
		
		do {
			try handler.perform([request])
		} catch {
			print("❌ CardCropper: Failed to perform rectangle detection: \(error)")
			completion(image) // Return original on error
		}
	}
	
	// Enhanced card rectangle detection with more lenient criteria
	private func findBestCardRectangle(_ observations: [VNRectangleObservation]) -> VNRectangleObservation? {
		print("🔍 CardCropper: Analyzing \(observations.count) rectangles for card detection...")
		
		// Sort by confidence first
		let sortedObservations = observations.sorted { $0.confidence > $1.confidence }
		
		// Strategy 1: Look for card-like rectangles with strict criteria
		let strictCandidates = sortedObservations.filter { rectangle in
			let aspectRatio = rectangle.boundingBox.width / rectangle.boundingBox.height
			let area = rectangle.boundingBox.width * rectangle.boundingBox.height
			
			// Trading card aspect ratio is approximately 0.714 (2.5:3.5)
			let isCardAspectRatio = aspectRatio >= 0.6 && aspectRatio <= 0.8
			let isReasonableSize = area >= 0.05 && area <= 0.9
			let isHighConfidence = rectangle.confidence >= 0.5
			
			print("   Strict check - Aspect: \(aspectRatio), Area: \(area), Confidence: \(rectangle.confidence)")
			print("      Card-like: \(isCardAspectRatio), Good size: \(isReasonableSize), High confidence: \(isHighConfidence)")
			
			return isCardAspectRatio && isReasonableSize && isHighConfidence
		}
		
		if let bestStrict = strictCandidates.first {
			print("✅ CardCropper: Found strict candidate")
			return bestStrict
		}
		
		// Strategy 2: More lenient criteria
		let lenientCandidates = sortedObservations.filter { rectangle in
			let aspectRatio = rectangle.boundingBox.width / rectangle.boundingBox.height
			let area = rectangle.boundingBox.width * rectangle.boundingBox.height
			
			// More lenient criteria
			let isRectangularish = aspectRatio >= 0.4 && aspectRatio <= 1.2
			let isReasonableSize = area >= 0.03 && area <= 0.95
			let isOkConfidence = rectangle.confidence >= 0.3
			
			print("   Lenient check - Aspect: \(aspectRatio), Area: \(area), Confidence: \(rectangle.confidence)")
			print("      Rectangular: \(isRectangularish), Good size: \(isReasonableSize), OK confidence: \(isOkConfidence)")
			
			return isRectangularish && isReasonableSize && isOkConfidence
		}
		
		if let bestLenient = lenientCandidates.first {
			print("✅ CardCropper: Found lenient candidate")
			return bestLenient
		}
		
		// Strategy 3: Just take the highest confidence rectangle if it's reasonable
		if let highestConfidence = sortedObservations.first {
			let area = highestConfidence.boundingBox.width * highestConfidence.boundingBox.height
			if area >= 0.02 && highestConfidence.confidence >= 0.2 {
				print("✅ CardCropper: Using highest confidence rectangle as fallback")
				return highestConfidence
			}
		}
		
		print("❌ CardCropper: No suitable rectangles found")
		return nil
	}
	
	private func cropImageWithCorrectOrientation(_ image: UIImage, to rectangle: VNRectangleObservation) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
		
		print("🖼️ CardCropper: Original image size: \(imageSize)")
		print("🔲 CardCropper: Rectangle bounds: \(rectangle.boundingBox)")
		
		// Use different padding for each edge to account for detection bias
		let topPadding: CGFloat = 0.03    // 3% extra at top
		let bottomPadding: CGFloat = 0.02  // 2% at bottom
		let sidePadding: CGFloat = 0.02    // 2% on sides
		
		// Convert normalized coordinates to image coordinates with asymmetric padding
		let topLeft = CGPoint(
			x: max(0, (rectangle.topLeft.x - sidePadding)) * imageSize.width,
			y: max(0, (1 - rectangle.topLeft.y - topPadding)) * imageSize.height
		)
		let topRight = CGPoint(
			x: min(1, (rectangle.topRight.x + sidePadding)) * imageSize.width,
			y: max(0, (1 - rectangle.topRight.y - topPadding)) * imageSize.height
		)
		let bottomLeft = CGPoint(
			x: max(0, (rectangle.bottomLeft.x - sidePadding)) * imageSize.width,
			y: min(imageSize.height, (1 - rectangle.bottomLeft.y + bottomPadding)) * imageSize.height
		)
		let bottomRight = CGPoint(
			x: min(imageSize.width, (rectangle.bottomRight.x + sidePadding)) * imageSize.width,
			y: min(imageSize.height, (1 - rectangle.bottomRight.y + bottomPadding)) * imageSize.height
		)
		
		print("📍 CardCropper: Corner points with padding - TL:\(topLeft), TR:\(topRight), BL:\(bottomLeft), BR:\(bottomRight)")
		
		// Create CIImage with proper orientation
		let ciImage = CIImage(cgImage: cgImage)
		
		guard let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection") else {
			print("❌ CardCropper: Failed to create perspective correction filter")
			return nil
		}
		
		perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)
		perspectiveCorrection.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
		perspectiveCorrection.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
		perspectiveCorrection.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
		perspectiveCorrection.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
		
		guard let outputImage = perspectiveCorrection.outputImage else {
			print("❌ CardCropper: Perspective correction failed")
			return nil
		}
		
		print("✅ CardCropper: Perspective correction successful, output extent: \(outputImage.extent)")
		
		// Convert back to UIImage
		let context = CIContext()
		guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
			print("❌ CardCropper: Failed to create final CGImage")
			return nil
		}
		
		// Create UIImage with correct orientation
		let correctedImage = UIImage(cgImage: correctedCGImage)
		
		// Fix orientation if needed
		let orientationFixedImage = self.fixImageOrientation(correctedImage)
		
		print("✅ CardCropper: Final image size: \(orientationFixedImage.size)")
		
		return orientationFixedImage
	}
	
	private func correctSkewedRectangle(
		topLeft: CGPoint,
		topRight: CGPoint,
		bottomLeft: CGPoint,
		bottomRight: CGPoint,
		imageSize: CGSize
	) -> (topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
		
		// Calculate the center of the detected rectangle
		let centerX = (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4
		let centerY = (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
		
		// Calculate average width and height
		let topWidth = abs(topRight.x - topLeft.x)
		let bottomWidth = abs(bottomRight.x - bottomLeft.x)
		let leftHeight = abs(bottomLeft.y - topLeft.y)
		let rightHeight = abs(bottomRight.y - topRight.y)
		
		let avgWidth = (topWidth + bottomWidth) / 2
		let avgHeight = (leftHeight + rightHeight) / 2
		
		// If the rectangle is too skewed, create a more rectangular version
		let skewThreshold: CGFloat = 0.3 // 30% difference is considered too skewed
		let widthSkew = abs(topWidth - bottomWidth) / max(topWidth, bottomWidth)
		let heightSkew = abs(leftHeight - rightHeight) / max(leftHeight, rightHeight)
		
		if widthSkew > skewThreshold || heightSkew > skewThreshold {
			print("🔧 CardCropper: Rectangle is skewed (width: \(widthSkew), height: \(heightSkew)), correcting...")
			
			// Create a more rectangular version centered on the detected rectangle
			let halfWidth = avgWidth / 2
			let halfHeight = avgHeight / 2
			
			let correctedTopLeft = CGPoint(
				x: max(0, centerX - halfWidth),
				y: max(0, centerY - halfHeight)
			)
			let correctedTopRight = CGPoint(
				x: min(imageSize.width, centerX + halfWidth),
				y: max(0, centerY - halfHeight)
			)
			let correctedBottomLeft = CGPoint(
				x: max(0, centerX - halfWidth),
				y: min(imageSize.height, centerY + halfHeight)
			)
			let correctedBottomRight = CGPoint(
				x: min(imageSize.width, centerX + halfWidth),
				y: min(imageSize.height, centerY + halfHeight)
			)
			
			return (correctedTopLeft, correctedTopRight, correctedBottomLeft, correctedBottomRight)
		}
		
		// Rectangle is not too skewed, use original points
		return (topLeft, topRight, bottomLeft, bottomRight)
	}
	
	// Fix image orientation to ensure cards are portrait
	private func fixImageOrientation(_ image: UIImage) -> UIImage {
		let size = image.size
		
		// If image is wider than tall, it might need rotation
		if size.width > size.height {
			print("🔄 CardCropper: Image is landscape (\(size.width)x\(size.height)), checking if it should be portrait...")
			
			// For trading cards, we expect them to be taller than wide
			// If we got a landscape image, try rotating it 90 degrees
			let rotatedImage = rotateImage(image, by: .pi/2) // 90 degrees
			print("🔄 CardCropper: Rotated to: \(rotatedImage.size)")
			return rotatedImage
		}
		
		return image
	}
	
	// Rotate image by specified angle
	private func rotateImage(_ image: UIImage, by angle: CGFloat) -> UIImage {
		let rotatedSize = CGRect(origin: .zero, size: image.size)
			.applying(CGAffineTransform(rotationAngle: angle))
			.size
		
		UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
		defer { UIGraphicsEndImageContext() }
		
		guard let context = UIGraphicsGetCurrentContext() else { return image }
		
		context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
		context.rotate(by: angle)
		context.scaleBy(x: 1.0, y: -1.0) // Fix mirroring
		
		let drawRect = CGRect(
			x: -image.size.width / 2,
			y: -image.size.height / 2,
			width: image.size.width,
			height: image.size.height
		)
		
		image.draw(in: drawRect)
		
		return UIGraphicsGetImageFromCurrentImageContext() ?? image
	}
	
	// Convert UIImage orientation to CGImagePropertyOrientation
	private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
		switch uiOrientation {
		case .up: return .up
		case .upMirrored: return .upMirrored
		case .down: return .down
		case .downMirrored: return .downMirrored
		case .left: return .left
		case .leftMirrored: return .leftMirrored
		case .right: return .right
		case .rightMirrored: return .rightMirrored
		@unknown default: return .up
		}
	}
	
	// Simple fallback crop method
	func simpleCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
		print("🔄 CardCropper: Trying simple crop method...")
		
		guard let cgImage = image.cgImage else {
			completion(nil)
			return
		}
		
		let request = VNDetectRectanglesRequest { request, error in
			guard let observations = request.results as? [VNRectangleObservation],
				  let bestRectangle = observations.first else {
				print("❌ Simple crop: No rectangles found")
				completion(image)
				return
			}
			
			print("✅ Simple crop: Using rectangle with confidence \(bestRectangle.confidence)")
			
			// Simple bounding box crop
			let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
			let cropRect = CGRect(
				x: bestRectangle.boundingBox.origin.x * imageSize.width,
				y: (1 - bestRectangle.boundingBox.origin.y - bestRectangle.boundingBox.height) * imageSize.height,
				width: bestRectangle.boundingBox.width * imageSize.width,
				height: bestRectangle.boundingBox.height * imageSize.height
			)
			
			print("📐 Simple crop rect: \(cropRect)")
			
			guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
				print("❌ Simple crop: Failed to crop")
				completion(image)
				return
			}
			
			let croppedImage = UIImage(cgImage: croppedCGImage)
			let orientationFixedImage = self.fixImageOrientation(croppedImage)
			completion(orientationFixedImage)
		}
		
		// Very lenient settings for simple crop
		request.minimumAspectRatio = 0.2
		request.maximumAspectRatio = 5.0
		request.minimumSize = 0.01
		request.minimumConfidence = 0.1
		
		let handler = VNImageRequestHandler(cgImage: cgImage, orientation: self.cgImageOrientation(from: image.imageOrientation), options: [:])
		
		do {
			try handler.perform([request])
		} catch {
			print("❌ Simple crop: Detection failed: \(error)")
			completion(image)
		}
	}
}
