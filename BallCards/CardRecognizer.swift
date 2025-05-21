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
