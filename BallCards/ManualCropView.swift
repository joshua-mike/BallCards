// ManualCropView.swift - DEAD SIMPLE VERSION THAT ACTUALLY WORKS
import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct ManualCropView: View {
	let image: UIImage
	let onCropComplete: (UIImage?) -> Void
	let onCancel: () -> Void
	
	@State private var topLeft: CGPoint = CGPoint(x: 0.15, y: 0.15)
	@State private var topRight: CGPoint = CGPoint(x: 0.85, y: 0.15)
	@State private var bottomLeft: CGPoint = CGPoint(x: 0.15, y: 0.85)
	@State private var bottomRight: CGPoint = CGPoint(x: 0.85, y: 0.85)
	
	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			
			VStack {
				// Header
				HStack {
					Button("Cancel") { onCancel() }
						.foregroundColor(.white)
					Spacer()
					Text("Adjust Card Edges")
						.foregroundColor(.white)
						.font(.headline)
					Spacer()
					Button("Crop") { performCrop() }
						.foregroundColor(.blue)
						.fontWeight(.semibold)
				}
				.padding()
				
				// Image with overlay - FIXED VERSION
				GeometryReader { geometry in
					ZStack {
						// Image
						Image(uiImage: image)
							.resizable()
							.aspectRatio(contentMode: .fit)
						
						// Overlay that actually works
						WorkingCropOverlay(
							topLeft: $topLeft,
							topRight: $topRight,
							bottomLeft: $bottomLeft,
							bottomRight: $bottomRight,
							containerSize: geometry.size
						)
					}
				}
				
				// Instructions
				Text("Drag the corners to match the card edges")
					.foregroundColor(.white)
					.padding()
			}
		}
	}
	
	private func performCrop() {
		print("🔧 Final corners: TL:\(topLeft) TR:\(topRight) BL:\(bottomLeft) BR:\(bottomRight)")
		
		// Apply perspective correction with proper coordinate handling
		let imageSize = image.size
		
		let topLeftImage = CGPoint(x: topLeft.x * imageSize.width, y: topLeft.y * imageSize.height)
		let topRightImage = CGPoint(x: topRight.x * imageSize.width, y: topRight.y * imageSize.height)
		let bottomLeftImage = CGPoint(x: bottomLeft.x * imageSize.width, y: bottomLeft.y * imageSize.height)
		let bottomRightImage = CGPoint(x: bottomRight.x * imageSize.width, y: bottomRight.y * imageSize.height)
		
		if let croppedImage = applyCrop(topLeft: topLeftImage, topRight: topRightImage, bottomLeft: bottomLeftImage, bottomRight: bottomRightImage) {
			onCropComplete(croppedImage)
		} else {
			onCropComplete(image)
		}
	}
	
	private func applyCrop(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage? {
		guard let cgImage = image.cgImage else {
			print("❌ Failed to get CGImage")
			return nil
		}
		
		print("🔧 Creating CIImage from original CGImage")
		let ciImage = CIImage(cgImage: cgImage)
		let imageHeight = ciImage.extent.height
		
		print("🔧 Original image extent: \(ciImage.extent)")
		print("🔧 Input corners (image coordinates):")
		print("   TL: \(topLeft), TR: \(topRight)")
		print("   BL: \(bottomLeft), BR: \(bottomRight)")
		
		// CRITICAL FIX: CIPerspectiveCorrection expects bottom-left origin
		// We need to flip Y coordinates AND ensure we're using the right coordinate system
		let correctedTopLeft = CGPoint(x: topLeft.x, y: imageHeight - topLeft.y)
		let correctedTopRight = CGPoint(x: topRight.x, y: imageHeight - topRight.y)
		let correctedBottomLeft = CGPoint(x: bottomLeft.x, y: imageHeight - bottomLeft.y)
		let correctedBottomRight = CGPoint(x: bottomRight.x, y: imageHeight - bottomRight.y)
		
		print("🔧 Corrected coordinates (Core Image coordinate system):")
		print("   TL: \(correctedTopLeft), TR: \(correctedTopRight)")
		print("   BL: \(correctedBottomLeft), BR: \(correctedBottomRight)")
		
		let perspectiveFilter = CIFilter.perspectiveCorrection()
		perspectiveFilter.inputImage = ciImage
		
		// IMPORTANT: Make sure we're setting the corners in the right order
		perspectiveFilter.topLeft = correctedTopLeft
		perspectiveFilter.topRight = correctedTopRight
		perspectiveFilter.bottomLeft = correctedBottomLeft
		perspectiveFilter.bottomRight = correctedBottomRight
		
		guard let outputImage = perspectiveFilter.outputImage else {
			print("❌ Perspective correction failed")
			return nil
		}
		
		print("🔧 Perspective correction output extent: \(outputImage.extent)")
		
		let context = CIContext()
		guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
			print("❌ Failed to create final CGImage")
			return nil
		}
		
		let finalImage = UIImage(cgImage: correctedCGImage, scale: image.scale, orientation: .up)
		print("✅ Final cropped image size: \(finalImage.size)")
		
		return finalImage
	}
}

// MARK: - Working Crop Overlay (Finally!)

struct WorkingCropOverlay: View {
	@Binding var topLeft: CGPoint
	@Binding var topRight: CGPoint
	@Binding var bottomLeft: CGPoint
	@Binding var bottomRight: CGPoint
	let containerSize: CGSize
	
	var body: some View {
		ZStack {
			// Crop boundary
			Path { path in
				let tl = CGPoint(x: topLeft.x * containerSize.width, y: topLeft.y * containerSize.height)
				let tr = CGPoint(x: topRight.x * containerSize.width, y: topRight.y * containerSize.height)
				let bl = CGPoint(x: bottomLeft.x * containerSize.width, y: bottomLeft.y * containerSize.height)
				let br = CGPoint(x: bottomRight.x * containerSize.width, y: bottomRight.y * containerSize.height)
				
				path.move(to: tl)
				path.addLine(to: tr)
				path.addLine(to: br)
				path.addLine(to: bl)
				path.closeSubpath()
			}
			.stroke(Color.white, lineWidth: 3)
			
			// Draggable corners
			DraggableCorner(position: $topLeft, label: "TL", containerSize: containerSize)
			DraggableCorner(position: $topRight, label: "TR", containerSize: containerSize)
			DraggableCorner(position: $bottomLeft, label: "BL", containerSize: containerSize)
			DraggableCorner(position: $bottomRight, label: "BR", containerSize: containerSize)
		}
	}
}

// MARK: - Draggable Corner That ACTUALLY Works

struct DraggableCorner: View {
	@Binding var position: CGPoint
	let label: String
	let containerSize: CGSize
	
	@State private var isDragging = false
	
	var body: some View {
		let screenPos = CGPoint(
			x: position.x * containerSize.width,
			y: position.y * containerSize.height
		)
		
		ZStack {
			Circle()
				.fill(Color.white)
				.frame(width: 30, height: 30)
			Circle()
				.stroke(Color.blue, lineWidth: 3)
				.frame(width: 30, height: 30)
			Text(label)
				.font(.caption2)
				.fontWeight(.bold)
				.foregroundColor(.blue)
		}
		.position(screenPos)
		.scaleEffect(isDragging ? 1.2 : 1.0)
		.gesture(
			DragGesture()
				.onChanged { value in
					isDragging = true
					
					// Convert absolute position to normalized coordinates
					let newX = max(0, min(1, value.location.x / containerSize.width))
					let newY = max(0, min(1, value.location.y / containerSize.height))
					
					position = CGPoint(x: newX, y: newY)
					
					print("📍 Dragging \(label) to normalized: (\(String(format: "%.3f", newX)), \(String(format: "%.3f", newY)))")
				}
				.onEnded { _ in
					isDragging = false
					print("✅ \(label) final position: \(position)")
				}
		)
	}
}
