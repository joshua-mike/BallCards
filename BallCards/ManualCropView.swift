// Simplified ManualCropView.swift - Debugging version
import SwiftUI
import UIKit

struct ManualCropView: View {
	let image: UIImage
	let onCropComplete: (UIImage?) -> Void
	let onCancel: () -> Void
	
	@State private var topLeft: CGPoint = CGPoint(x: 0.1, y: 0.1)
	@State private var topRight: CGPoint = CGPoint(x: 0.9, y: 0.1)
	@State private var bottomLeft: CGPoint = CGPoint(x: 0.1, y: 0.9)
	@State private var bottomRight: CGPoint = CGPoint(x: 0.9, y: 0.9)
	
	var body: some View {
		ZStack {
			Color.black
				.ignoresSafeArea()
			
			VStack(spacing: 20) {
				// Header with debug info
				VStack(spacing: 10) {
					Text("Adjust Crop Area")
						.font(.title2)
						.fontWeight(.semibold)
						.foregroundColor(.white)
					
					Text("Drag the corners to match the card edges")
						.font(.subheadline)
						.foregroundColor(.white.opacity(0.8))
					
					// Debug coordinates
					Text("TL: (\(String(format: "%.3f", topLeft.x)), \(String(format: "%.3f", topLeft.y))) TR: (\(String(format: "%.3f", topRight.x)), \(String(format: "%.3f", topRight.y)))")
						.font(.caption)
						.foregroundColor(.yellow)
					
					Text("BL: (\(String(format: "%.3f", bottomLeft.x)), \(String(format: "%.3f", bottomLeft.y))) BR: (\(String(format: "%.3f", bottomRight.x)), \(String(format: "%.3f", bottomRight.y)))")
						.font(.caption)
						.foregroundColor(.yellow)
				}
				.padding()
				
				// Simple image with overlay - NO COMPLEX CALCULATIONS
				ZStack {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.background(Color.gray)
					
					// Use the simple overlay but with better debugging
					DebugCropOverlay(
						topLeft: $topLeft,
						topRight: $topRight,
						bottomLeft: $bottomLeft,
						bottomRight: $bottomRight
					)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color.gray.opacity(0.3))
				
				// Action buttons
				HStack(spacing: 20) {
					Button("Cancel") {
						onCancel()
					}
					.foregroundColor(.white)
					.padding(.horizontal, 24)
					.padding(.vertical, 12)
					.background(Color.red)
					.cornerRadius(8)
					
					Spacer()
					
					Button("Reset") {
						withAnimation(.easeInOut(duration: 0.3)) {
							// Set to card-like proportions
							topLeft = CGPoint(x: 0.15, y: 0.15)
							topRight = CGPoint(x: 0.85, y: 0.15)
							bottomLeft = CGPoint(x: 0.15, y: 0.85)
							bottomRight = CGPoint(x: 0.85, y: 0.85)
						}
					}
					.foregroundColor(.white)
					.padding(.horizontal, 24)
					.padding(.vertical, 12)
					.background(Color.orange)
					.cornerRadius(8)
					
					Button("Test Crop") {
						// For debugging - just show what we would crop without applying it
						testCrop()
					}
					.foregroundColor(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 12)
					.background(Color.blue)
					.cornerRadius(8)
					
					Spacer()
					
					Button("Crop") {
						performCrop()
					}
					.foregroundColor(.black)
					.fontWeight(.semibold)
					.padding(.horizontal, 24)
					.padding(.vertical, 12)
					.background(Color.white)
					.cornerRadius(8)
				}
				.padding()
			}
		}
		.onAppear {
			print("🖼️ ManualCropView appeared with image size: \(image.size)")
			// Set reasonable initial corners
			topLeft = CGPoint(x: 0.15, y: 0.15)
			topRight = CGPoint(x: 0.85, y: 0.15)
			bottomLeft = CGPoint(x: 0.15, y: 0.85)
			bottomRight = CGPoint(x: 0.85, y: 0.85)
		}
	}
	
	private func testCrop() {
		print("🧪 TEST CROP - What would be cropped:")
		let imageSize = image.size
		
		let corners = [
			CGPoint(x: topLeft.x * imageSize.width, y: topLeft.y * imageSize.height),
			CGPoint(x: topRight.x * imageSize.width, y: topRight.y * imageSize.height),
			CGPoint(x: bottomRight.x * imageSize.width, y: bottomRight.y * imageSize.height),
			CGPoint(x: bottomLeft.x * imageSize.width, y: bottomLeft.y * imageSize.height)
		]
		
		print("   Image size: \(imageSize)")
		print("   Corner coordinates in pixels:")
		corners.enumerated().forEach { index, corner in
			print("     Corner \(index): \(corner)")
		}
		
		// Calculate the bounding box of the corners
		let minX = corners.map { $0.x }.min() ?? 0
		let maxX = corners.map { $0.x }.max() ?? imageSize.width
		let minY = corners.map { $0.y }.min() ?? 0
		let maxY = corners.map { $0.y }.max() ?? imageSize.height
		
		let boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
		print("   Bounding rectangle: \(boundingRect)")
		print("   Crop percentage: \(String(format: "%.1f", (boundingRect.width * boundingRect.height) / (imageSize.width * imageSize.height) * 100))%")
	}
	
	private func performCrop() {
		print("🔧 Starting crop with corners:")
		print("   TL: \(topLeft), TR: \(topRight)")
		print("   BL: \(bottomLeft), BR: \(bottomRight)")
		
		// Convert normalized coordinates back to image coordinates
		let imageSize = image.size
		
		let corners = [
			CGPoint(x: topLeft.x * imageSize.width, y: topLeft.y * imageSize.height),
			CGPoint(x: topRight.x * imageSize.width, y: topRight.y * imageSize.height),
			CGPoint(x: bottomRight.x * imageSize.width, y: bottomRight.y * imageSize.height),
			CGPoint(x: bottomLeft.x * imageSize.width, y: bottomLeft.y * imageSize.height)
		]
		
		print("🔧 Image coordinates:")
		corners.enumerated().forEach { index, corner in
			print("   Corner \(index): \(corner)")
		}
		
		// Apply perspective correction WITHOUT automatic rotation first
		if let croppedImage = applyPerspectiveCorrectionOnly(to: image, corners: corners) {
			print("✅ Perspective correction successful")
			onCropComplete(croppedImage)
		} else {
			print("❌ Perspective correction failed, returning original image")
			onCropComplete(image)
		}
	}
	
	// Separate method for just perspective correction without rotation
	private func applyPerspectiveCorrectionOnly(to image: UIImage, corners: [CGPoint]) -> UIImage? {
		guard corners.count == 4, let cgImage = image.cgImage else {
			print("❌ Invalid corners or CGImage")
			return nil
		}
		
		print("🔧 Creating CIImage from CGImage")
		let ciImage = CIImage(cgImage: cgImage)
		
		// Validate corners to prevent NaN values
		for (index, corner) in corners.enumerated() {
			if corner.x.isNaN || corner.y.isNaN || corner.x.isInfinite || corner.y.isInfinite {
				print("❌ Invalid corner \(index): \(corner)")
				return nil
			}
		}
		
		guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
			print("❌ Failed to create perspective correction filter")
			return nil
		}
		
		print("🔧 Setting up perspective correction filter")
		perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
		perspectiveFilter.setValue(CIVector(cgPoint: corners[0]), forKey: "inputTopLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[1]), forKey: "inputTopRight")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[3]), forKey: "inputBottomLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[2]), forKey: "inputBottomRight")
		
		guard let outputImage = perspectiveFilter.outputImage else {
			print("❌ Perspective correction filter failed to produce output")
			return nil
		}
		
		print("🔧 Converting CIImage back to UIImage")
		let context = CIContext()
		guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
			print("❌ Failed to create CGImage from corrected CIImage")
			return nil
		}
		
		// Create UIImage with proper orientation - NO ROTATION YET
		let correctedImage = UIImage(cgImage: correctedCGImage, scale: image.scale, orientation: .up)
		print("✅ Perspective correction completed. Size: \(correctedImage.size)")
		
		// For now, let's NOT rotate and see what we get
		print("📋 Returning image without rotation for debugging")
		return correctedImage
	}
	
	private func applyPerspectiveCorrection(to image: UIImage, corners: [CGPoint]) -> UIImage? {
		guard corners.count == 4, let cgImage = image.cgImage else {
			print("❌ Invalid corners or CGImage")
			return nil
		}
		
		print("🔧 Creating CIImage from CGImage")
		let ciImage = CIImage(cgImage: cgImage)
		
		// Validate corners to prevent NaN values
		for (index, corner) in corners.enumerated() {
			if corner.x.isNaN || corner.y.isNaN || corner.x.isInfinite || corner.y.isInfinite {
				print("❌ Invalid corner \(index): \(corner)")
				return nil
			}
		}
		
		guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
			print("❌ Failed to create perspective correction filter")
			return nil
		}
		
		print("🔧 Setting up perspective correction filter")
		perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
		perspectiveFilter.setValue(CIVector(cgPoint: corners[0]), forKey: "inputTopLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[1]), forKey: "inputTopRight")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[3]), forKey: "inputBottomLeft")
		perspectiveFilter.setValue(CIVector(cgPoint: corners[2]), forKey: "inputBottomRight")
		
		guard let outputImage = perspectiveFilter.outputImage else {
			print("❌ Perspective correction filter failed to produce output")
			return nil
		}
		
		print("🔧 Converting CIImage back to UIImage")
		let context = CIContext()
		guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
			print("❌ Failed to create CGImage from corrected CIImage")
			return nil
		}
		
		// Create UIImage with proper orientation
		let correctedImage = UIImage(cgImage: correctedCGImage, scale: image.scale, orientation: .up)
		print("✅ Perspective correction completed. New size: \(correctedImage.size)")
		
		// Force portrait orientation for cards
		return ensurePortraitOrientation(correctedImage)
	}
	
	private func ensurePortraitOrientation(_ image: UIImage) -> UIImage {
		let size = image.size
		print("🔄 Checking orientation - Size: \(size)")
		
		// Cards should always be in portrait mode (taller than wide)
		// If width >= height, rotate to make it portrait
		if size.width >= size.height {
			print("🔄 Image is landscape or square, rotating to portrait")
			return rotateImage90Degrees(image)
		} else {
			print("✅ Image is already portrait")
			return image
		}
	}
	
	private func rotateImage90Degrees(_ image: UIImage) -> UIImage {
		guard let cgImage = image.cgImage else {
			print("❌ Failed to get CGImage for rotation")
			return image
		}
		
		print("🔄 Rotating image 90 degrees")
		
		let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
		let rotatedSize = CGSize(width: originalSize.height, height: originalSize.width)
		
		print("🔄 Original size: \(originalSize), Rotated size: \(rotatedSize)")
		
		UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
		defer { UIGraphicsEndImageContext() }
		
		guard let context = UIGraphicsGetCurrentContext() else {
			print("❌ Failed to get graphics context")
			return image
		}
		
		// Move to center and rotate 90 degrees clockwise
		context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
		context.rotate(by: .pi / 2)  // 90 degrees clockwise
		
		let drawRect = CGRect(
			x: -originalSize.width / 2,
			y: -originalSize.height / 2,
			width: originalSize.width,
			height: originalSize.height
		)
		
		context.draw(cgImage, in: drawRect)
		
		let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
		print("✅ Rotation completed. Final size: \(rotatedImage.size)")
		
		return rotatedImage
	}
}

// MARK: - Simple Debug Crop Overlay

struct DebugCropOverlay: View {
	@Binding var topLeft: CGPoint
	@Binding var topRight: CGPoint
	@Binding var bottomLeft: CGPoint
	@Binding var bottomRight: CGPoint
	
	private let cornerSize: CGFloat = 30
	
	var body: some View {
		GeometryReader { geometry in
			ZStack {
				// Draw crop boundary - EXACTLY as the coordinates specify
				Path { path in
					let tl = CGPoint(x: topLeft.x * geometry.size.width, y: topLeft.y * geometry.size.height)
					let tr = CGPoint(x: topRight.x * geometry.size.width, y: topRight.y * geometry.size.height)
					let bl = CGPoint(x: bottomLeft.x * geometry.size.width, y: bottomLeft.y * geometry.size.height)
					let br = CGPoint(x: bottomRight.x * geometry.size.width, y: bottomRight.y * geometry.size.height)
					
					path.move(to: tl)
					path.addLine(to: tr)
					path.addLine(to: br)
					path.addLine(to: bl)
					path.closeSubpath()
				}
				.stroke(Color.white, lineWidth: 3)
				
				// Semi-transparent fill to show crop area
				Path { path in
					let tl = CGPoint(x: topLeft.x * geometry.size.width, y: topLeft.y * geometry.size.height)
					let tr = CGPoint(x: topRight.x * geometry.size.width, y: topRight.y * geometry.size.height)
					let bl = CGPoint(x: bottomLeft.x * geometry.size.width, y: bottomLeft.y * geometry.size.height)
					let br = CGPoint(x: bottomRight.x * geometry.size.width, y: bottomRight.y * geometry.size.height)
					
					path.move(to: tl)
					path.addLine(to: tr)
					path.addLine(to: br)
					path.addLine(to: bl)
					path.closeSubpath()
				}
				.fill(Color.blue.opacity(0.2))
				
				// Corner handles with labels
				cornerHandle(label: "TL", position: topLeft, geometry: geometry) { newPosition in
					topLeft = newPosition
				}
				cornerHandle(label: "TR", position: topRight, geometry: geometry) { newPosition in
					topRight = newPosition
				}
				cornerHandle(label: "BL", position: bottomLeft, geometry: geometry) { newPosition in
					bottomLeft = newPosition
				}
				cornerHandle(label: "BR", position: bottomRight, geometry: geometry) { newPosition in
					bottomRight = newPosition
				}
			}
		}
	}
	
	@ViewBuilder
	private func cornerHandle(
		label: String,
		position: CGPoint,
		geometry: GeometryProxy,
		onPositionChange: @escaping (CGPoint) -> Void
	) -> some View {
		let displayPosition = CGPoint(
			x: position.x * geometry.size.width,
			y: position.y * geometry.size.height
		)
		
		ZStack {
			Circle()
				.fill(Color.white)
				.frame(width: cornerSize, height: cornerSize)
			
			Circle()
				.stroke(Color.blue, lineWidth: 3)
				.frame(width: cornerSize, height: cornerSize)
			
			Text(label)
				.font(.caption2)
				.fontWeight(.bold)
				.foregroundColor(.blue)
		}
		.position(displayPosition)
		.gesture(
			DragGesture()
				.onChanged { value in
					// Simple direct conversion - no complex calculations
					let newX = max(0, min(1, value.location.x / geometry.size.width))
					let newY = max(0, min(1, value.location.y / geometry.size.height))
					let newPosition = CGPoint(x: newX, y: newY)
					onPositionChange(newPosition)
				}
		)
	}
}
