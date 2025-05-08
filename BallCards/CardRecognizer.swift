// CardRecognizer.swift
import Vision
import UIKit

class CardRecognizer {
	static let shared = CardRecognizer()
	
	// Extract text from image and identify card details
	func extractCardInfo(from image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		guard let cgImage = image.cgImage else {
			completion(nil)
			return
		}
		
		// Create a new Vision request to recognize text
		let request = VNRecognizeTextRequest { (request, error) in
			if let error = error {
				print("Failed to recognize text: \(error)")
				completion(nil)
				return
			}
			
			guard let observations = request.results as? [VNRecognizedTextObservation] else {
				completion(nil)
				return
			}
			
			// Process all the recognized text
			let recognizedStrings = observations.compactMap { observation in
				observation.topCandidates(1).first?.string
			}
			
			// Extract card information from recognized text
			let cardInfo = self.parseCardInfo(from: recognizedStrings)
			completion(cardInfo)
		}
		
		// Configure the text recognition request
		request.recognitionLevel = .accurate
		
		// Create a request handler
		let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
		
		do {
			// Perform the text recognition request
			try requestHandler.perform([request])
		} catch {
			print("Failed to perform image request: \(error)")
			completion(nil)
		}
	}
	
	// Parse recognized text to extract player name, year, team, etc.
	private func parseCardInfo(from strings: [String]) -> [String: String] {
		var cardInfo = [String: String]()
		
		// Join all strings for easier processing
		let text = strings.joined(separator: " ")
		
		// Try to identify player name
		// This is a simple implementation - in a real app you'd want more sophisticated parsing
		// based on patterns common in baseball cards
		
		// Look for year (4-digit number between 1900-2025)
		if let yearRange = text.range(of: #"19\d{2}|20[0-2]\d"#, options: .regularExpression) {
			let year = String(text[yearRange])
			cardInfo["year"] = year
		}
		
		// Try to identify common baseball teams
		let teams = ["Yankees", "Red Sox", "Cubs", "Dodgers", "Cardinals", "Giants",
					 "Braves", "Astros", "Mets", "Phillies", "Angels", "Blue Jays",
					 "White Sox", "Brewers", "Athletics", "Padres", "Royals", "Marlins",
					 "Pirates", "Rangers", "Mariners", "Rays", "Nationals", "Tigers",
					 "Rockies", "Orioles", "Diamondbacks", "Twins", "Indians", "Guardians", "Reds"]
		
		for team in teams {
			if text.contains(team) {
				cardInfo["team"] = team
				break
			}
		}
		
		// Try to extract player name
		// This is a very basic approach - a real implementation would be more sophisticated
		// For now, we'll just take the first two "words" that might be a name
		// A real app would use NLP to identify person names
		
		let potentialNameWords = strings
			.flatMap { $0.components(separatedBy: " ") }
			.filter { $0.count > 1 && $0.first?.isUppercase == true }
			.filter { !teams.contains($0) }  // Exclude team names
			.prefix(2)
		
		if !potentialNameWords.isEmpty {
			cardInfo["playerName"] = potentialNameWords.joined(separator: " ")
		}
		
		// Look for card number (often formatted as #123 or No. 123)
		if let cardNumberRange = text.range(of: #"#\d+|No\.\s*\d+"#, options: .regularExpression) {
			let cardNumber = String(text[cardNumberRange])
				.replacingOccurrences(of: "#", with: "")
				.replacingOccurrences(of: "No.", with: "")
				.trimmingCharacters(in: .whitespacesAndNewlines)
			cardInfo["cardNumber"] = cardNumber
		}
		
		return cardInfo
	}
}

// CameraViewController.swift (Real camera implementation)
import UIKit
import AVFoundation
import SwiftUI

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

protocol CameraViewControllerDelegate: AnyObject {
	func didCaptureImage(_ image: UIImage)
	func didCancel()
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
	weak var delegate: CameraViewControllerDelegate?
	var isFrontSide = true
	
	private let captureSession = AVCaptureSession()
	private var capturePhotoOutput: AVCapturePhotoOutput?
	private var previewLayer: AVCaptureVideoPreviewLayer?
	
	private let cancelButton = UIButton(type: .system)
	private let captureButton = UIButton(type: .system)
	private let titleLabel = UILabel()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupCamera()
		setupUI()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if !captureSession.isRunning {
			DispatchQueue.global(qos: .userInitiated).async {
				self.captureSession.startRunning()
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		if captureSession.isRunning {
			captureSession.stopRunning()
		}
	}
	
	private func setupCamera() {
		captureSession.sessionPreset = .photo
		
		guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
			  let input = try? AVCaptureDeviceInput(device: backCamera) else {
			return
		}
		
		if captureSession.canAddInput(input) {
			captureSession.addInput(input)
		}
		
		capturePhotoOutput = AVCapturePhotoOutput()
		
		if let photoOutput = capturePhotoOutput, captureSession.canAddOutput(photoOutput) {
			captureSession.addOutput(photoOutput)
		}
		
		previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		previewLayer?.videoGravity = .resizeAspectFill
		previewLayer?.frame = view.bounds
		
		if let previewLayer = previewLayer {
			view.layer.addSublayer(previewLayer)
		}
	}
	
	private func setupUI() {
		// Card outline overlay
		let overlayView = UIView()
		overlayView.translatesAutoresizingMaskIntoConstraints = false
		overlayView.layer.borderColor = UIColor.white.cgColor
		overlayView.layer.borderWidth = 2
		overlayView.layer.cornerRadius = 8
		
		// Title label
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.text = isFrontSide ? "Capture Front of Card" : "Capture Back of Card"
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center
		titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
		titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
		titleLabel.layer.cornerRadius = 8
		titleLabel.layer.masksToBounds = true
		
		// Capture button
		captureButton.translatesAutoresizingMaskIntoConstraints = false
		captureButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
		captureButton.tintColor = .white
		captureButton.contentVerticalAlignment = .fill
		captureButton.contentHorizontalAlignment = .fill
		captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
		
		// Cancel button
		cancelButton.translatesAutoresizingMaskIntoConstraints = false
		cancelButton.setTitle("Cancel", for: .normal)
		cancelButton.tintColor = .white
		cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
		
		// Add subviews
		[overlayView, titleLabel, captureButton, cancelButton].forEach { view.addSubview($0) }
		
		// Layout constraints
		NSLayoutConstraint.activate([
			overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			overlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			overlayView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
			overlayView.heightAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 1.4),  // Standard card ratio
			
			titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			
			captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
			captureButton.widthAnchor.constraint(equalToConstant: 80),
			captureButton.heightAnchor.constraint(equalToConstant: 80),
			
			cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			cancelButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor)
		])
	}
	
	@objc private func capturePhoto() {
		guard let capturePhotoOutput = capturePhotoOutput else { return }
		
		let settings = AVCapturePhotoSettings()
		settings.flashMode = .auto
		
		capturePhotoOutput.capturePhoto(with: settings, delegate: self)
	}
	
	@objc private func cancelButtonTapped() {
		delegate?.didCancel()
	}
	
	// MARK: - AVCapturePhotoCaptureDelegate
	
	func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard let data = photo.fileDataRepresentation(),
			  let image = UIImage(data: data) else {
			return
		}
		
		delegate?.didCaptureImage(image)
	}
}

// Update ContentView to use RealCameraView
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
