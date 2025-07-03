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
			// Ensure we have a visible background
			Color.black
				.ignoresSafeArea()
			
			VStack(spacing: 20) {
				// Header
				VStack(spacing: 10) {
					Text("Adjust Crop Area")
						.font(.title2)
						.fontWeight(.semibold)
						.foregroundColor(.white)
					
					Text("Drag the corners to match the card edges")
						.font(.subheadline)
						.foregroundColor(.white.opacity(0.8))
				}
				.padding()
				
				// Image with basic overlay
				ZStack {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.background(Color.gray) // Ensure image is visible
					
					// Simple corner overlay
					SimpleCropOverlay(
						topLeft: $topLeft,
						topRight: $topRight,
						bottomLeft: $bottomLeft,
						bottomRight: $bottomRight
					)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color.gray.opacity(0.3)) // Debug background
				
				// Action buttons
				HStack(spacing: 20) {
					Button("Cancel") {
						print("🔄 Cancel button tapped")
						onCancel()
					}
					.foregroundColor(.white)
					.padding(.horizontal, 24)
					.padding(.vertical, 12)
					.background(Color.red)
					.cornerRadius(8)
					
					Spacer()
					
					Button("Reset") {
						print("🔄 Reset button tapped")
						withAnimation(.easeInOut(duration: 0.3)) {
							topLeft = CGPoint(x: 0.1, y: 0.1)
							topRight = CGPoint(x: 0.9, y: 0.1)
							bottomLeft = CGPoint(x: 0.1, y: 0.9)
							bottomRight = CGPoint(x: 0.9, y: 0.9)
						}
					}
					.foregroundColor(.white)
					.padding(.horizontal, 24)
					.padding(.vertical, 12)
					.background(Color.orange)
					.cornerRadius(8)
					
					Spacer()
					
					Button("Crop") {
						print("✂️ Crop button tapped")
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
		}
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
		
		// Apply perspective correction
		if let croppedImage = applyPerspectiveCorrection(to: image, corners: corners) {
			print("✅ Perspective correction successful, returning cropped image")
			onCropComplete(croppedImage)
		} else {
			print("❌ Perspective correction failed, returning original image")
			onCropComplete(image)
		}
	}
	
	private func applyPerspectiveCorrection(to image: UIImage, corners: [CGPoint]) -> UIImage? {
		guard corners.count == 4, let cgImage = image.cgImage else {
			print("❌ Invalid corners or CGImage")
			return nil
		}
		
		print("🔧 Creating CIImage from CGImage")
		let ciImage = CIImage(cgImage: cgImage)
		
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
		
		let correctedImage = UIImage(cgImage: correctedCGImage)
		print("✅ Perspective correction completed. New size: \(correctedImage.size)")
		
		// Apply orientation correction if needed
		return ensurePortraitOrientation(correctedImage)
	}
	
	private func ensurePortraitOrientation(_ image: UIImage) -> UIImage {
		let size = image.size
		
		// If image is significantly wider than tall, rotate to portrait
		if size.width > size.height * 1.3 {
			print("🔄 Rotating landscape image to portrait")
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

// MARK: - Simplified Crop Overlay

struct SimpleCropOverlay: View {
	@Binding var topLeft: CGPoint
	@Binding var topRight: CGPoint
	@Binding var bottomLeft: CGPoint
	@Binding var bottomRight: CGPoint
	
	private let cornerSize: CGFloat = 30
	
	var body: some View {
		GeometryReader { geometry in
			ZStack {
				// Draw crop boundary
				Path { path in
					let tl = convertToDisplayCoordinates(topLeft, size: geometry.size)
					let tr = convertToDisplayCoordinates(topRight, size: geometry.size)
					let bl = convertToDisplayCoordinates(bottomLeft, size: geometry.size)
					let br = convertToDisplayCoordinates(bottomRight, size: geometry.size)
					
					path.move(to: tl)
					path.addLine(to: tr)
					path.addLine(to: br)
					path.addLine(to: bl)
					path.closeSubpath()
				}
				.stroke(Color.white, lineWidth: 3)
				
				// Corner handles
				cornerHandle(for: "TL", position: topLeft, geometry: geometry) { newPosition in
					topLeft = newPosition
				}
				cornerHandle(for: "TR", position: topRight, geometry: geometry) { newPosition in
					topRight = newPosition
				}
				cornerHandle(for: "BL", position: bottomLeft, geometry: geometry) { newPosition in
					bottomLeft = newPosition
				}
				cornerHandle(for: "BR", position: bottomRight, geometry: geometry) { newPosition in
					bottomRight = newPosition
				}
			}
		}
	}
	
	@ViewBuilder
	private func cornerHandle(
		for label: String,
		position: CGPoint,
		geometry: GeometryProxy,
		onPositionChange: @escaping (CGPoint) -> Void
	) -> some View {
		let displayPosition = convertToDisplayCoordinates(position, size: geometry.size)
		
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
					let newPosition = convertToNormalizedCoordinates(value.location, size: geometry.size)
					onPositionChange(newPosition)
				}
		)
	}
	
	private func convertToDisplayCoordinates(_ normalizedPoint: CGPoint, size: CGSize) -> CGPoint {
		return CGPoint(
			x: normalizedPoint.x * size.width,
			y: normalizedPoint.y * size.height
		)
	}
	
	private func convertToNormalizedCoordinates(_ displayPoint: CGPoint, size: CGSize) -> CGPoint {
		let x = max(0, min(1, displayPoint.x / size.width))
		let y = max(0, min(1, displayPoint.y / size.height))
		return CGPoint(x: x, y: y)
	}
}
