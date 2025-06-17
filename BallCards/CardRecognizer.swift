// CardRecognizer.swift - Updated with auto-cropping
import Vision
import UIKit

class CardRecognizer {
	static let shared = CardRecognizer()
	
	// Extract text from image with optional auto-cropping
	func extractCardInfo(from image: UIImage, autoCrop: Bool = true, completion: @escaping ([String: String]?, UIImage?) -> Void) {
		
		if autoCrop {
			// First try to crop the card automatically
			CardCropper.shared.detectAndCropCard(from: image) { croppedImage in
				let finalImage = croppedImage ?? image
				self.performTextRecognition(on: finalImage) { cardInfo in
					completion(cardInfo, finalImage)
				}
			}
		} else {
			// Use original image without cropping
			performTextRecognition(on: image) { cardInfo in
				completion(cardInfo, image)
			}
		}
	}
	
	// Legacy method for backward compatibility
	func extractCardInfo(from image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		extractCardInfo(from: image, autoCrop: true) { cardInfo, _ in
			completion(cardInfo)
		}
	}
	
	// Perform text recognition on the image
	private func performTextRecognition(on image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		guard let cgImage = image.cgImage else {
			completion(nil)
			return
		}
		
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
		request.usesLanguageCorrection = true
		
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
		
		// Look for manufacturer/series info (common card manufacturers)
		let manufacturers = ["Topps", "Panini", "Upper Deck", "Bowman", "Donruss", "Fleer", "Score"]
		for manufacturer in manufacturers {
			if text.contains(manufacturer) {
				cardInfo["manufacturer"] = manufacturer
				break
			}
		}
		
		return cardInfo
	}
}
