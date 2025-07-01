import Vision
import UIKit
import CoreImage
import Accelerate

class CardCropper {
	static let shared = CardCropper()
	
	// Main detection method using document scanning techniques
	func detectAndCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
		guard let cgImage = image.cgImage else {
			print("❌ CardCropper: Failed to get CGImage")
			completion(nil)
			return
		}
		
		print("🔍 CardCropper: Starting detection on image size: \(cgImage.width)x\(cgImage.height)")
		
		// Use document-style edge detection approach
		DispatchQueue.global(qos: .userInitiated).async {
			if let croppedImage = self.detectCardUsingDocumentScanning(image) {
				print("✅ CardCropper: Document scanning successful")
				DispatchQueue.main.async {
					completion(croppedImage)
				}
			} else {
				print("❌ CardCropper: Document scanning failed, using fallback")
				let fallback = self.intelligentFallbackCrop(image)
				DispatchQueue.main.async {
					completion(fallback)
				}
			}
		}
	}
	
	// MARK: - Document Scanning Approach (Similar to TurboScan)
	
	private func detectCardUsingDocumentScanning(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		// Step 1: Convert to grayscale and resize for processing
		guard let processedImage = prepareImageForProcessing(cgImage) else {
			print("❌ Failed to prepare image for processing")
			return nil
		}
		
		// Step 2: Apply Gaussian blur to reduce noise
		guard let blurredImage = applyGaussianBlur(processedImage) else {
			print("❌ Failed to apply blur")
			return nil
		}
		
		// Step 3: Apply Canny edge detection
		guard let edgeImage = applyCannyEdgeDetection(blurredImage) else {
			print("❌ Failed to detect edges")
			return nil
		}
		
		// Step 4: Find contours and detect rectangles
		if let cardCorners = findCardCorners(edgeImage, originalSize: CGSize(width: cgImage.width, height: cgImage.height)) {
			print("✅ Found card corners: \(cardCorners)")
			
			// Step 5: Apply perspective correction
			return perspectiveCorrectCard(image, corners: cardCorners)
		}
		
		print("❌ Could not find card corners")
		return nil
	}
	
	// MARK: - Image Processing Steps
	
	private func prepareImageForProcessing(_ cgImage: CGImage) -> CGImage? {
		let width = cgImage.width
		let height = cgImage.height
		
		// Resize to reasonable processing size (similar to what document scanners do)
		let maxDimension: CGFloat = 1024
		let scale = min(maxDimension / CGFloat(width), maxDimension / CGFloat(height))
		
		let newWidth = Int(CGFloat(width) * scale)
		let newHeight = Int(CGFloat(height) * scale)
		
		let colorSpace = CGColorSpaceCreateDeviceGray()
		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
		
		guard let context = CGContext(data: nil,
									width: newWidth,
									height: newHeight,
									bitsPerComponent: 8,
									bytesPerRow: newWidth,
									space: colorSpace,
									bitmapInfo: bitmapInfo.rawValue) else {
			return nil
		}
		
		context.interpolationQuality = .high
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
		
		return context.makeImage()
	}
	
	private func applyGaussianBlur(_ cgImage: CGImage) -> CGImage? {
		let ciImage = CIImage(cgImage: cgImage)
		
		guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
		blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
		blurFilter.setValue(2.0, forKey: kCIInputRadiusKey) // Small blur to reduce noise
		
		guard let outputImage = blurFilter.outputImage else { return nil }
		
		let context = CIContext()
		return context.createCGImage(outputImage, from: outputImage.extent)
	}
	
	private func applyCannyEdgeDetection(_ cgImage: CGImage) -> CGImage? {
		// Implement Canny-like edge detection using Core Image
		let ciImage = CIImage(cgImage: cgImage)
		
		// Apply edge detection filter
		guard let edgeFilter = CIFilter(name: "CIEdges") else { return nil }
		edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
		edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
		
		guard let edgeOutput = edgeFilter.outputImage else { return nil }
		
		// Apply threshold to create binary edge image
		guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else {
			// Fallback if CIColorThreshold is not available
			let context = CIContext()
			return context.createCGImage(edgeOutput, from: edgeOutput.extent)
		}
		
		thresholdFilter.setValue(edgeOutput, forKey: kCIInputImageKey)
		thresholdFilter.setValue(0.1, forKey: "inputThreshold") // Adjust threshold as needed
		
		guard let thresholdOutput = thresholdFilter.outputImage else { return nil }
		
		let context = CIContext()
		return context.createCGImage(thresholdOutput, from: thresholdOutput.extent)
	}
	
	private func findCardCorners(_ edgeImage: CGImage, originalSize: CGSize) -> [CGPoint]? {
		let width = edgeImage.width
		let height = edgeImage.height
		
		guard let data = edgeImage.dataProvider?.data,
			  let bytes = CFDataGetBytePtr(data) else {
			return nil
		}
		
		// Find edge pixels
		var edgePoints: [CGPoint] = []
		let threshold: UInt8 = 128
		
		for y in 0..<height {
			for x in 0..<width {
				let pixelIndex = y * width + x
				if bytes[pixelIndex] > threshold {
					edgePoints.append(CGPoint(x: x, y: y))
				}
			}
		}
		
		guard edgePoints.count > 100 else {
			print("❌ Not enough edge points found: \(edgePoints.count)")
			return nil
		}
		
		print("✅ Found \(edgePoints.count) edge points")
		
		// Find the convex hull of edge points
		let hull = convexHull(edgePoints)
		
		guard hull.count >= 4 else {
			print("❌ Convex hull has too few points: \(hull.count)")
			return nil
		}
		
		// Find the best 4-sided approximation of the hull (Douglas-Peucker style)
		let approximatedCorners = approximatePolygon(hull, targetCorners: 4)
		
		guard approximatedCorners.count == 4 else {
			print("❌ Could not approximate to 4 corners, got \(approximatedCorners.count)")
			return nil
		}
		
		// Scale corners back to original image size
		let scaleX = originalSize.width / CGFloat(width)
		let scaleY = originalSize.height / CGFloat(height)
		
		let scaledCorners = approximatedCorners.map { point in
			CGPoint(x: point.x * scaleX, y: point.y * scaleY)
		}
		
		// Sort corners in proper order: top-left, top-right, bottom-right, bottom-left
		return sortCornersForPerspectiveCorrection(scaledCorners)
	}
	
	// MARK: - Geometric Algorithms
	
	private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
		// Graham scan algorithm for convex hull
		guard points.count > 2 else { return points }
		
		// Find the bottom-most point (and leftmost in case of tie)
		let start = points.min { p1, p2 in
			if p1.y != p2.y {
				return p1.y < p2.y
			}
			return p1.x < p2.x
		}!
		
		// Sort points by polar angle with respect to start point
		let sortedPoints = points.filter { $0 != start }.sorted { p1, p2 in
			let angle1 = atan2(p1.y - start.y, p1.x - start.x)
			let angle2 = atan2(p2.y - start.y, p2.x - start.x)
			if angle1 != angle2 {
				return angle1 < angle2
			}
			// If angles are equal, prefer closer point
			let dist1 = distance(start, p1)
			let dist2 = distance(start, p2)
			return dist1 < dist2
		}
		
		// Build convex hull
		var hull: [CGPoint] = [start]
		
		for point in sortedPoints {
			// Remove points that would create a right turn
			while hull.count > 1 && crossProduct(hull[hull.count-2], hull[hull.count-1], point) <= 0 {
				hull.removeLast()
			}
			hull.append(point)
		}
		
		return hull
	}
	
	private func approximatePolygon(_ points: [CGPoint], targetCorners: Int) -> [CGPoint] {
		// Simplified polygon approximation
		guard points.count > targetCorners else { return points }
		
		// Find the 4 points that are most likely to be corners of a rectangle
		let centroid = CGPoint(
			x: points.map { $0.x }.reduce(0, +) / CGFloat(points.count),
			y: points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
		)
		
		// Divide into quadrants and find the most extreme point in each
		var topLeft: CGPoint?
		var topRight: CGPoint?
		var bottomLeft: CGPoint?
		var bottomRight: CGPoint?
		
		var maxTL = CGFloat.infinity
		var maxTR = CGFloat.infinity
		var maxBL = CGFloat.infinity
		var maxBR = CGFloat.infinity
		
		for point in points {
			let dx = point.x - centroid.x
			let dy = point.y - centroid.y
			
			if dx <= 0 && dy <= 0 { // Top-left quadrant
				let dist = dx * dx + dy * dy
				if dist < maxTL {
					maxTL = dist
					topLeft = point
				}
			} else if dx > 0 && dy <= 0 { // Top-right quadrant
				let dist = dx * dx + dy * dy
				if dist < maxTR {
					maxTR = dist
					topRight = point
				}
			} else if dx <= 0 && dy > 0 { // Bottom-left quadrant
				let dist = dx * dx + dy * dy
				if dist < maxBL {
					maxBL = dist
					bottomLeft = point
				}
			} else if dx > 0 && dy > 0 { // Bottom-right quadrant
				let dist = dx * dx + dy * dy
				if dist < maxBR {
					maxBR = dist
					bottomRight = point
				}
			}
		}
		
		var corners: [CGPoint] = []
		if let tl = topLeft { corners.append(tl) }
		if let tr = topRight { corners.append(tr) }
		if let br = bottomRight { corners.append(br) }
		if let bl = bottomLeft { corners.append(bl) }
		
		return corners
	}
	
	private func sortCornersForPerspectiveCorrection(_ corners: [CGPoint]) -> [CGPoint] {
		guard corners.count == 4 else { return corners }
		
		// Find centroid
		let centroid = CGPoint(
			x: corners.map { $0.x }.reduce(0, +) / 4,
			y: corners.map { $0.y }.reduce(0, +) / 4
		)
		
		// Sort by angle from centroid
		let sortedCorners = corners.sorted { p1, p2 in
			let angle1 = atan2(p1.y - centroid.y, p1.x - centroid.x)
			let angle2 = atan2(p2.y - centroid.y, p2.x - centroid.x)
			return angle1 < angle2
		}
		
		// The sorted corners should now be in order: top-left, top-right, bottom-right, bottom-left
		// But we need to ensure they're in the correct quadrants
		var topLeft = sortedCorners[0]
		var topRight = sortedCorners[1]
		var bottomRight = sortedCorners[2]
		var bottomLeft = sortedCorners[3]
		
		// Verify and adjust if needed
		if topLeft.x > topRight.x {
			swap(&topLeft, &topRight)
		}
		if bottomLeft.x > bottomRight.x {
			swap(&bottomLeft, &bottomRight)
		}
		if topLeft.y > bottomLeft.y {
			swap(&topLeft, &bottomLeft)
		}
		if topRight.y > bottomRight.y {
			swap(&topRight, &bottomRight)
		}
		
		return [topLeft, topRight, bottomRight, bottomLeft]
	}
	
	// MARK: - Perspective Correction
	
	private func perspectiveCorrectCard(_ image: UIImage, corners: [CGPoint]) -> UIImage? {
		guard corners.count == 4, let cgImage = image.cgImage else { return nil }
		
		let topLeft = corners[0]
		let topRight = corners[1]
		let bottomRight = corners[2]
		let bottomLeft = corners[3]
		
		print("📍 Applying perspective correction with corners:")
		print("   TL: \(topLeft), TR: \(topRight)")
		print("   BL: \(bottomLeft), BR: \(bottomRight)")
		
		// Calculate the dimensions of the corrected card
		let topWidth = distance(topLeft, topRight)
		let bottomWidth = distance(bottomLeft, bottomRight)
		let leftHeight = distance(topLeft, bottomLeft)
		let rightHeight = distance(topRight, bottomRight)
		
		let outputWidth = max(topWidth, bottomWidth)
		let outputHeight = max(leftHeight, rightHeight)
		
		print("📐 Output dimensions: \(outputWidth) x \(outputHeight)")
		
		// Apply perspective correction
		let ciImage = CIImage(cgImage: cgImage)
		
		guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
			return nil
		}
		
		perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
		perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
		perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
		
		guard let outputImage = perspectiveFilter.outputImage else {
			return nil
		}
		
		let context = CIContext()
		guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
			return nil
		}
		
		let correctedImage = UIImage(cgImage: correctedCGImage)
		return ensurePortraitOrientation(correctedImage)
	}
	
	// MARK: - Fallback Methods
	
	private func intelligentFallbackCrop(_ image: UIImage) -> UIImage? {
		print("🔄 Applying intelligent fallback crop")
		
		// Try to find the card using contrast analysis
		if let contrastCropped = cropUsingContrastAnalysis(image) {
			return contrastCropped
		}
		
		// Final fallback: smart center crop
		return smartCenterCrop(image)
	}
	
	private func cropUsingContrastAnalysis(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		let width = cgImage.width
		let height = cgImage.height
		
		guard let data = cgImage.dataProvider?.data,
			  let bytes = CFDataGetBytePtr(data) else {
			return nil
		}
		
		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		
		// Sample the image to find areas of high contrast (likely card edges)
		let sampleStep = 20
		var minX = width, maxX = 0
		var minY = height, maxY = 0
		
		for y in stride(from: sampleStep, to: height - sampleStep, by: sampleStep) {
			for x in stride(from: sampleStep, to: width - sampleStep, by: sampleStep) {
				let contrast = calculateLocalContrast(bytes, x: x, y: y, bytesPerRow: bytesPerRow)
				
				if contrast > 0.2 { // Threshold for significant contrast
					minX = min(minX, x)
					maxX = max(maxX, x)
					minY = min(minY, y)
					maxY = max(maxY, y)
				}
			}
		}
		
		// Add padding and validate
		let padding = 50
		minX = max(0, minX - padding)
		minY = max(0, minY - padding)
		maxX = min(width, maxX + padding)
		maxY = min(height, maxY + padding)
		
		let cropWidth = maxX - minX
		let cropHeight = maxY - minY
		
		guard cropWidth > width / 4 && cropHeight > height / 4 else {
			return nil
		}
		
		let cropRect = CGRect(x: minX, y: minY, width: cropWidth, height: cropHeight)
		
		guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
			return nil
		}
		
		let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
		return ensurePortraitOrientation(croppedImage)
	}
	
	private func smartCenterCrop(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
		let aspectRatio = imageSize.width / imageSize.height
		
		// Create a crop rect that's likely to contain the card
		var cropRect: CGRect
		
		if aspectRatio > 1.2 {
			// Landscape - crop to portrait card ratio
			let cardAspectRatio: CGFloat = 2.5 / 3.5
			let cropHeight = imageSize.height * 0.8
			let cropWidth = cropHeight * cardAspectRatio
			
			cropRect = CGRect(
				x: (imageSize.width - cropWidth) / 2,
				y: (imageSize.height - cropHeight) / 2,
				width: cropWidth,
				height: cropHeight
			)
		} else {
			// Portrait or square - crop 75% from center
			let cropScale: CGFloat = 0.75
			let cropWidth = imageSize.width * cropScale
			let cropHeight = imageSize.height * cropScale
			
			cropRect = CGRect(
				x: (imageSize.width - cropWidth) / 2,
				y: (imageSize.height - cropHeight) / 2,
				width: cropWidth,
				height: cropHeight
			)
		}
		
		guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
			return image
		}
		
		let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
		return ensurePortraitOrientation(croppedImage)
	}
	
	// MARK: - Helper Functions
	
	private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
		let dx = p1.x - p2.x
		let dy = p1.y - p2.y
		return sqrt(dx * dx + dy * dy)
	}
	
	private func crossProduct(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
		return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
	}
	
	private func calculateLocalContrast(_ bytes: UnsafePointer<UInt8>, x: Int, y: Int, bytesPerRow: Int) -> Double {
		let bytesPerPixel = 4
		let centerIndex = y * bytesPerRow + x * bytesPerPixel
		
		let centerBrightness = Double(bytes[centerIndex]) // Red channel for grayscale
		
		// Sample surrounding pixels
		var brightnesses: [Double] = []
		let radius = 10
		
		for dy in -radius...radius {
			for dx in -radius...radius {
				let nx = x + dx
				let ny = y + dy
				
				if nx >= 0 && ny >= 0 && nx < bytesPerRow / bytesPerPixel && ny < bytesPerRow / bytesPerPixel {
					let index = ny * bytesPerRow + nx * bytesPerPixel
					brightnesses.append(Double(bytes[index]))
				}
			}
		}
		
		guard !brightnesses.isEmpty else { return 0 }
		
		let avgBrightness = brightnesses.reduce(0, +) / Double(brightnesses.count)
		let variance = brightnesses.map { pow($0 - avgBrightness, 2) }.reduce(0, +) / Double(brightnesses.count)
		
		return sqrt(variance) / 255.0 // Normalize to 0-1
	}
	
	private func ensurePortraitOrientation(_ image: UIImage) -> UIImage {
		let size = image.size
		
		// If image is significantly wider than tall, rotate to portrait
		if size.width > size.height * 1.3 {
			return rotateImage90Degrees(image)
		}
		
		return image
	}
	
	private func rotateImage90Degrees(_ image: UIImage) -> UIImage {
		guard let cgImage = image.cgImage else { return image }
		
		let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
		let rotatedSize = CGSize(width: originalSize.height, height: originalSize.width)
		
		UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
		defer { UIGraphicsEndImageContext() }
		
		guard let context = UIGraphicsGetCurrentContext() else { return image }
		
		context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
		context.rotate(by: .pi / 2)
		
		let drawRect = CGRect(
			x: -originalSize.width / 2,
			y: -originalSize.height / 2,
			width: originalSize.width,
			height: originalSize.height
		)
		
		context.draw(cgImage, in: drawRect)
		
		return UIGraphicsGetImageFromCurrentImageContext() ?? image
	}
}
