// CameraView.swift
import SwiftUI
import AVFoundation

// SwiftUI wrapper for UIKit camera
struct RealCameraView: UIViewControllerRepresentable {
	@Binding var image: UIImage?
	@Binding var isFrontSide: Bool
	@Environment(\.presentationMode) var presentationMode
	var onImageCaptured: (UIImage?) -> Void
	
	func makeUIViewController(context: Context) -> CameraViewController {
		let controller = CameraViewController()
		controller.delegate = context.coordinator
		controller.isFrontSide = isFrontSide
		return controller
	}
	
	func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
		// Update properties if needed
		uiViewController.isFrontSide = isFrontSide
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, CameraViewControllerDelegate {
		let parent: RealCameraView
		
		init(_ parent: RealCameraView) {
			self.parent = parent
		}
		
		func didCaptureImage(_ image: UIImage) {
			parent.image = image
			parent.onImageCaptured(image)
			parent.presentationMode.wrappedValue.dismiss()
		}
		
		func didCancel() {
			parent.presentationMode.wrappedValue.dismiss()
		}
	}
}

// SwiftUI Camera View
struct CameraView: View {
	@Binding var image: UIImage?
	@Binding var isFrontSide: Bool
	@Environment(\.presentationMode) var presentationMode
	var onImageCaptured: (UIImage?) -> Void
	
	var body: some View {
		RealCameraView(
			image: $image,
			isFrontSide: $isFrontSide,
			onImageCaptured: onImageCaptured
		)
	}
}

#Preview {
	Text("Camera Preview Placeholder")
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black)
		.foregroundColor(.white)
}
