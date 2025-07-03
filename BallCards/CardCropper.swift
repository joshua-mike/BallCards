import Vision
import UIKit
import CoreImage
import Accelerate

class CardCropper {
	static let shared = CardCropper()
	
	// Main detection method - simplified and more focused approach
	func detectAndCropCard(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
		guard let cgImage = image.cgImage else {
			print("❌ CardCropper: Failed to get CGImage")
			completion(nil)
			return
		}
		
		print("🔍 CardCropper: Starting detection on image size: \(cgImage.width)x\(cgImage.height)")
		
		DispatchQueue.global(qos: .userInitiated).async {
			// Try multiple approaches in order of sophistication
			if let croppedImage = self.detectCardWithAdaptiveThreshold(image) {
				print("✅ CardCropper: Adaptive threshold detection successful")
				DispatchQueue.main.async {
					completion(croppedImage)
				}
			} else if let croppedImage = self.detectCardWithContourAnalysis(image) {
				print("✅ CardCropper: Contour analysis successful")
				DispatchQueue.main.async {
					completion(croppedImage)
				}
			} else {
				print("❌ CardCropper: All methods failed, using smart fallback")
				let fallback = self.smartCenterCrop(image)
				DispatchQueue.main.async {
					completion(fallback)
				}
			}
		}
	}
	
	// MARK: - Method 1: Adaptive Threshold Detection
	
	private func detectCardWithAdaptiveThreshold(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		// Resize to working size for faster processing
		guard let resizedImage = resizeImageForProcessing(cgImage, maxDimension: 800) else {
			return nil
		}
		
		let width = resizedImage.width
		let height = resizedImage.height
		
		guard let data = resizedImage.dataProvider?.data,
			  let bytes = CFDataGetBytePtr(data) else {
			return nil
		}
		
		print("🔍 Processing resized image: \(width)x\(height)")
		
		// Convert to grayscale and apply adaptive thresholding
		var grayPixels: [UInt8] = []
		let bytesPerPixel = 4
		
		for y in 0..<height {
			for x in 0..<width {
				let pixelIndex = y * width * bytesPerPixel + x * bytesPerPixel
				let r = Int(bytes[pixelIndex])
				let g = Int(bytes[pixelIndex + 1])
				let b = Int(bytes[pixelIndex + 2])
				let gray = UInt8((r + g + b) / 3)
				grayPixels.append(gray)
			}
		}
		
		// Apply adaptive threshold to find card edges
		let thresholdedPixels = applyAdaptiveThreshold(grayPixels, width: width, height: height)
		
		// Find the largest rectangular contour
		if let cardBounds = findLargestRectangularContour(thresholdedPixels, width: width, height: height) {
			print("✅ Found card bounds: \(cardBounds)")
			
			// Scale back to original image size
			let scaleX = CGFloat(cgImage.width) / CGFloat(width)
			let scaleY = CGFloat(cgImage.height) / CGFloat(height)
			
			let scaledBounds = CGRect(
				x: cardBounds.minX * scaleX,
				y: cardBounds.minY * scaleY,
				width: cardBounds.width * scaleX,
				height: cardBounds.height * scaleY
			)
			
			return cropImageToBounds(image, bounds: scaledBounds)
		}
		
		return nil
	}
	
	private func applyAdaptiveThreshold(_ grayPixels: [UInt8], width: Int, height: Int) -> [Bool] {
		var result: [Bool] = Array(repeating: false, count: grayPixels.count)
		let windowSize = 15
		let C = 10 // Constant subtracted from mean
		
		for y in 0..<height {
			for x in 0..<width {
				let pixelIndex = y * width + x
				
				// Calculate local mean
				var sum = 0
				var count = 0
				
				for dy in -windowSize/2...windowSize/2 {
					for dx in -windowSize/2...windowSize/2 {
						let nx = x + dx
						let ny = y + dy
						
						if nx >= 0 && nx < width && ny >= 0 && ny < height {
							let neighborIndex = ny * width + nx
							sum += Int(grayPixels[neighborIndex])
							count += 1
						}
					}
				}
				
				let localMean = count > 0 ? sum / count : 128
				let threshold = max(0, localMean - C)
				
				// Pixel is foreground if it's significantly darker than local mean
				result[pixelIndex] = Int(grayPixels[pixelIndex]) < threshold
			}
		}
		
		return result
	}
	
	private func findLargestRectangularContour(_ binaryPixels: [Bool], width: Int, height: Int) -> CGRect? {
		// Use a simpler approach: find the bounding box of the largest connected component
		// that has a reasonable aspect ratio for a card
		
		var visited = Array(repeating: false, count: binaryPixels.count)
		var bestBounds: CGRect?
		var bestArea: CGFloat = 0
		
		for y in 0..<height {
			for x in 0..<width {
				let index = y * width + x
				
				if binaryPixels[index] && !visited[index] {
					// Found an unvisited foreground pixel - start flood fill
					let bounds = floodFillAndGetBounds(binaryPixels, visited: &visited, startX: x, startY: y, width: width, height: height)
					
					if let bounds = bounds {
						let area = bounds.width * bounds.height
						let aspectRatio = bounds.width / bounds.height
						
						// Check if this looks like a card (reasonable size and aspect ratio)
						let minArea = CGFloat(width * height) * 0.1 // At least 10% of image
						let maxArea = CGFloat(width * height) * 0.8 // At most 80% of image
						let minAspectRatio: CGFloat = 0.5
						let maxAspectRatio: CGFloat = 1.5
						
						if area > minArea && area < maxArea &&
						   aspectRatio > minAspectRatio && aspectRatio < maxAspectRatio &&
						   area > bestArea {
							bestBounds = bounds
							bestArea = area
						}
					}
				}
			}
		}
		
		return bestBounds
	}
	
	private func floodFillAndGetBounds(_ binaryPixels: [Bool], visited: inout [Bool], startX: Int, startY: Int, width: Int, height: Int) -> CGRect? {
		var stack: [(Int, Int)] = [(startX, startY)]
		var minX = startX, maxX = startX
		var minY = startY, maxY = startY
		var pixelCount = 0
		
		while !stack.isEmpty {
			let (x, y) = stack.removeLast()
			let index = y * width + x
			
			if x < 0 || x >= width || y < 0 || y >= height || visited[index] || !binaryPixels[index] {
				continue
			}
			
			visited[index] = true
			pixelCount += 1
			
			minX = min(minX, x)
			maxX = max(maxX, x)
			minY = min(minY, y)
			maxY = max(maxY, y)
			
			// Add neighbors to stack
			stack.append((x + 1, y))
			stack.append((x - 1, y))
			stack.append((x, y + 1))
			stack.append((x, y - 1))
		}
		
		// Only return bounds if we found enough pixels
		guard pixelCount > 100 else { return nil }
		
		return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
	}
	
	// MARK: - Method 2: Contour Analysis with Better Filtering
	
	private func detectCardWithContourAnalysis(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		// Apply edge detection with better filtering
		guard let edgeImage = createFilteredEdgeImage(cgImage) else {
			return nil
		}
		
		// Find card-like contours
		if let cardBounds = findCardContour(edgeImage, originalSize: CGSize(width: cgImage.width, height: cgImage.height)) {
			return cropImageToBounds(image, bounds: cardBounds)
		}
		
		return nil
	}
	
	private func createFilteredEdgeImage(_ cgImage: CGImage) -> CGImage? {
		let ciImage = CIImage(cgImage: cgImage)
		
		// 1. Convert to grayscale
		guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return nil }
		grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
		grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
		
		guard let grayscaleImage = grayscaleFilter.outputImage else { return nil }
		
		// 2. Apply slight blur to reduce noise
		guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
		blurFilter.setValue(grayscaleImage, forKey: kCIInputImageKey)
		blurFilter.setValue(1.0, forKey: kCIInputRadiusKey)
		
		guard let blurredImage = blurFilter.outputImage else { return nil }
		
		// 3. Apply edge detection
		guard let edgeFilter = CIFilter(name: "CIEdges") else { return nil }
		edgeFilter.setValue(blurredImage, forKey: kCIInputImageKey)
		edgeFilter.setValue(1.5, forKey: kCIInputIntensityKey)
		
		guard let edgeImage = edgeFilter.outputImage else { return nil }
		
		// 4. Apply morphological closing to connect nearby edges
		guard let morphologyFilter = CIFilter(name: "CIMorphologyGradient") else {
			// Fallback without morphology
			let context = CIContext()
			return context.createCGImage(edgeImage, from: edgeImage.extent)
		}
		
		morphologyFilter.setValue(edgeImage, forKey: kCIInputImageKey)
		morphologyFilter.setValue(2, forKey: kCIInputRadiusKey)
		
		guard let morphologyImage = morphologyFilter.outputImage else { return nil }
		
		let context = CIContext()
		return context.createCGImage(morphologyImage, from: morphologyImage.extent)
	}
	
	private func findCardContour(_ edgeImage: CGImage, originalSize: CGSize) -> CGRect? {
		let width = edgeImage.width
		let height = edgeImage.height
		
		guard let data = edgeImage.dataProvider?.data,
			  let bytes = CFDataGetBytePtr(data) else {
			return nil
		}
		
		// Sample edge points more selectively
		var edgePoints: [CGPoint] = []
		let threshold: UInt8 = 100
		let sampleStep = 3 // Sample every 3rd pixel to reduce noise
		
		for y in stride(from: 0, to: height, by: sampleStep) {
			for x in stride(from: 0, to: width, by: sampleStep) {
				let pixelIndex = y * width + x
				if bytes[pixelIndex] > threshold {
					edgePoints.append(CGPoint(x: x, y: y))
				}
			}
		}
		
		print("✅ Found \(edgePoints.count) edge points (sampled)")
		
		// Filter edge points to remove outliers
		let filteredPoints = filterOutlierPoints(edgePoints, imageSize: CGSize(width: width, height: height))
		print("✅ After filtering: \(filteredPoints.count) edge points")
		
		guard filteredPoints.count > 50 && filteredPoints.count < 10000 else {
			print("❌ Invalid number of edge points: \(filteredPoints.count)")
			return nil
		}
		
		// Find bounding rectangle of filtered points
		let minX = filteredPoints.map { $0.x }.min() ?? 0
		let maxX = filteredPoints.map { $0.x }.max() ?? CGFloat(width)
		let minY = filteredPoints.map { $0.y }.min() ?? 0
		let maxY = filteredPoints.map { $0.y }.max() ?? CGFloat(height)
		
		let boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
		
		// Validate the bounding rectangle
		let area = boundingRect.width * boundingRect.height
		let imageArea = CGFloat(width * height)
		let aspectRatio = boundingRect.width / boundingRect.height
		
		guard area > imageArea * 0.1 && area < imageArea * 0.9 &&
			  aspectRatio > 0.4 && aspectRatio < 1.8 else {
			print("❌ Bounding rectangle failed validation")
			return nil
		}
		
		// Scale back to original size
		let scaleX = originalSize.width / CGFloat(width)
		let scaleY = originalSize.height / CGFloat(height)
		
		return CGRect(
			x: boundingRect.minX * scaleX,
			y: boundingRect.minY * scaleY,
			width: boundingRect.width * scaleX,
			height: boundingRect.height * scaleY
		)
	}
	
	private func filterOutlierPoints(_ points: [CGPoint], imageSize: CGSize) -> [CGPoint] {
		guard points.count > 10 else { return points }
		
		// Remove points that are too close to image edges (likely noise)
		let margin: CGFloat = 20
		let edgeFiltered = points.filter { point in
			point.x > margin && point.x < imageSize.width - margin &&
			point.y > margin && point.y < imageSize.height - margin
		}
		
		// Remove isolated points (points with no nearby neighbors)
		let neighborRadius: CGFloat = 15
		let neighborFiltered = edgeFiltered.filter { point in
			let nearbyCount = edgeFiltered.filter { other in
				let dx = point.x - other.x
				let dy = point.y - other.y
				return dx * dx + dy * dy < neighborRadius * neighborRadius
			}.count
			
			return nearbyCount >= 3 // Must have at least 2 nearby neighbors (plus itself)
		}
		
		return neighborFiltered
	}
	
	// MARK: - Helper Methods
	
	private func resizeImageForProcessing(_ cgImage: CGImage, maxDimension: CGFloat) -> CGImage? {
		let width = cgImage.width
		let height = cgImage.height
		
		let scale = min(maxDimension / CGFloat(width), maxDimension / CGFloat(height))
		
		// Don't upscale
		guard scale < 1.0 else { return cgImage }
		
		let newWidth = Int(CGFloat(width) * scale)
		let newHeight = Int(CGFloat(height) * scale)
		
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
		
		guard let context = CGContext(data: nil,
									width: newWidth,
									height: newHeight,
									bitsPerComponent: 8,
									bytesPerRow: newWidth * 4,
									space: colorSpace,
									bitmapInfo: bitmapInfo.rawValue) else {
			return nil
		}
		
		context.interpolationQuality = .high
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
		
		return context.makeImage()
	}
	
	private func cropImageToBounds(_ image: UIImage, bounds: CGRect) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
		let clampedBounds = bounds.intersection(CGRect(origin: .zero, size: imageSize))
		
		guard !clampedBounds.isEmpty else {
			return nil
		}
		
		// Add some padding to ensure we don't cut off the card edges
		let paddingPercent: CGFloat = 0.02 // 2% padding
		let paddingX = clampedBounds.width * paddingPercent
		let paddingY = clampedBounds.height * paddingPercent
		
		let paddedBounds = CGRect(
			x: max(0, clampedBounds.minX - paddingX),
			y: max(0, clampedBounds.minY - paddingY),
			width: min(imageSize.width - max(0, clampedBounds.minX - paddingX), clampedBounds.width + 2 * paddingX),
			height: min(imageSize.height - max(0, clampedBounds.minY - paddingY), clampedBounds.height + 2 * paddingY)
		)
		
		guard let croppedCGImage = cgImage.cropping(to: paddedBounds) else {
			return nil
		}
		
		let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
		return ensurePortraitOrientation(croppedImage)
	}
	
	private func smartCenterCrop(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else { return nil }
		
		print("🔄 Applying smart center crop")
		
		let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
		let aspectRatio = imageSize.width / imageSize.height
		
		// Create a crop rect based on typical card photography scenarios
		var cropRect: CGRect
		
		if aspectRatio > 1.3 {
			// Landscape image - assume card is in center, crop to card aspect ratio
			let cardAspectRatio: CGFloat = 2.5 / 3.5 // Standard trading card
			let cropHeight = imageSize.height * 0.75
			let cropWidth = cropHeight * cardAspectRatio
			
			cropRect = CGRect(
				x: (imageSize.width - cropWidth) / 2,
				y: (imageSize.height - cropHeight) / 2,
				width: cropWidth,
				height: cropHeight
			)
		} else {
			// Portrait or square - crop 70% from center
			let cropScale: CGFloat = 0.7
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
		let rotatedSize = CGSize(width: originalSize.width, height: originalSize.height)
		
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
