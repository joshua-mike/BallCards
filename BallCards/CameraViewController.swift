// CameraViewController.swift
import UIKit
import AVFoundation

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
		
		// Update title when view appears (fixes the title bug)
		updateTitleText()
		
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
		
		// Title label - UPDATED: Use helper method for initial setup
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		updateTitleText() // Use the helper method
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
		
		// Layout constraints (same as before)
		NSLayoutConstraint.activate([
			overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			overlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			overlayView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
			overlayView.heightAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 1.4),
			
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
	
	func updateTitle() {
		updateTitleText()
	}

	// Keep the existing private method
	private func updateTitleText() {
		titleLabel.text = isFrontSide ? "Capture Front of Card" : "Capture Back of Card"
	}
}
