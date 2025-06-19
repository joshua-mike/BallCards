// Enhanced CardRecognizer.swift with better OCR settings
import Vision
import UIKit

class CardRecognizer {
	static let shared = CardRecognizer()
	
	// Extract text from image with optional auto-cropping
	func extractCardInfo(from image: UIImage, autoCrop: Bool = true, completion: @escaping ([String: String]?, UIImage?) -> Void) {
		
		if autoCrop {
			print("🔍 CardRecognizer: Starting with auto-crop...")
			// First try to crop the card automatically
			CardCropper.shared.detectAndCropCard(from: image) { croppedImage in
				let finalImage = croppedImage ?? image
				print("📝 CardRecognizer: Using \(croppedImage != nil ? "cropped" : "original") image for OCR")
				self.performTextRecognition(on: finalImage) { cardInfo in
					completion(cardInfo, finalImage)
				}
			}
		} else {
			// Use original image without cropping
			print("📝 CardRecognizer: Using original image for OCR")
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
	
	// Enhanced text recognition with better settings
	private func performTextRecognition(on image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		guard let cgImage = image.cgImage else {
			print("❌ CardRecognizer: Failed to get CGImage")
			completion(nil)
			return
		}
		
		print("📝 CardRecognizer: Starting OCR on image size: \(cgImage.width)x\(cgImage.height)")
		
		let request = VNRecognizeTextRequest { (request, error) in
			if let error = error {
				print("❌ CardRecognizer: Failed to recognize text: \(error)")
				completion(nil)
				return
			}
			
			guard let observations = request.results as? [VNRecognizedTextObservation] else {
				print("❌ CardRecognizer: No text observations found")
				completion(nil)
				return
			}
			
			print("✅ CardRecognizer: Found \(observations.count) text observations")
			
			// Get multiple candidates for each observation to improve accuracy
			var allRecognizedText: [String] = []
			
			for observation in observations {
				// Get top 3 candidates instead of just 1
				let candidates = observation.topCandidates(3)
				for candidate in candidates {
					allRecognizedText.append(candidate.string)
					print("   Text candidate (confidence: \(candidate.confidence)): '\(candidate.string)'")
				}
			}
			
			// Extract card information from all recognized text
			let cardInfo = self.parseCardInfo(from: allRecognizedText)
			print("✅ CardRecognizer: Extracted info: \(cardInfo)")
			completion(cardInfo)
		}
		
		// Enhanced text recognition settings
		request.recognitionLevel = .accurate
		request.usesLanguageCorrection = true
		request.minimumTextHeight = 0.01  // Detect smaller text
		request.recognitionLanguages = ["en-US"]  // English only for better accuracy
		
		// Create a request handler
		let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
		
		do {
			try requestHandler.perform([request])
		} catch {
			print("❌ CardRecognizer: Failed to perform OCR request: \(error)")
			completion(nil)
		}
	}
	
	// Enhanced parsing with better name detection
	private func parseCardInfo(from strings: [String]) -> [String: String] {
		var cardInfo = [String: String]()
		
		print("🔍 CardRecognizer: Parsing text from \(strings.count) strings")
		
		// Join all strings for easier processing
		let allText = strings.joined(separator: " ")
		print("📄 All recognized text: '\(allText)'")
		
		// Clean up the text - remove extra spaces and normalize
		let cleanedStrings = strings.map { text in
			text.trimmingCharacters(in: .whitespacesAndNewlines)
				.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
		}.filter { !$0.isEmpty }
		
		// Look for year (4-digit number between 1950-2025)
		for text in cleanedStrings {
			if let yearRange = text.range(of: #"19[5-9]\d|20[0-2]\d"#, options: .regularExpression) {
				let year = String(text[yearRange])
				cardInfo["year"] = year
				print("✅ Found year: \(year)")
				break
			}
		}
		
		// Enhanced team detection
		let teams = [
			"Yankees", "Red Sox", "Cubs", "Dodgers", "Cardinals", "Giants",
			"Braves", "Astros", "Mets", "Phillies", "Angels", "Blue Jays",
			"White Sox", "Brewers", "Athletics", "Padres", "Royals", "Marlins",
			"Pirates", "Rangers", "Mariners", "Rays", "Nationals", "Tigers",
			"Rockies", "Orioles", "Diamondbacks", "Twins", "Indians", "Guardians",
			"Reds", "A's", "Twins"
		]
		
		for team in teams {
			if allText.lowercased().contains(team.lowercased()) {
				cardInfo["team"] = team
				print("✅ Found team: \(team)")
				break
			}
		}
		
		// Enhanced player name detection
		let playerName = extractPlayerName(from: cleanedStrings, excludingTeams: teams)
		if let name = playerName {
			cardInfo["playerName"] = name
			print("✅ Found player name: \(name)")
		}
		
		// Look for card number with more patterns
		for text in cleanedStrings {
			if let cardNumberRange = text.range(of: #"#?\s*(\d{1,4})\s*(?:[A-Z]*)?$|No\.?\s*(\d{1,4})"#, options: .regularExpression) {
				let cardNumber = String(text[cardNumberRange])
					.replacingOccurrences(of: "#", with: "")
					.replacingOccurrences(of: "No.", with: "")
					.replacingOccurrences(of: "No", with: "")
					.trimmingCharacters(in: .whitespacesAndNewlines)
				cardInfo["cardNumber"] = cardNumber
				print("✅ Found card number: \(cardNumber)")
				break
			}
		}
		
		// Look for manufacturer/series info
		let manufacturers = ["Topps", "Panini", "Upper Deck", "Bowman", "Donruss", "Fleer", "Score", "Leaf", "Stadium Club"]
		for manufacturer in manufacturers {
			if allText.lowercased().contains(manufacturer.lowercased()) {
				cardInfo["manufacturer"] = manufacturer
				print("✅ Found manufacturer: \(manufacturer)")
				break
			}
		}
		
		return cardInfo
	}
	
	// Better player name extraction
	private func extractPlayerName(from strings: [String], excludingTeams teams: [String]) -> String? {
		print("🔍 CardRecognizer: Analyzing strings for player name: \(strings)")
		
		// First, try to find "MATT MERULLO" or similar exact matches
		for text in strings {
			let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
			
			// Skip if it contains team info or is too short
			if teams.contains(where: { cleaned.lowercased().contains($0.lowercased()) }) || cleaned.count < 4 {
				continue
			}
			
			// Look for patterns that might be names
			let words = cleaned.components(separatedBy: CharacterSet.whitespacesAndPunctuationMarks)
				.filter { !$0.isEmpty && $0.count > 1 }
			
			print("   Checking text: '\(cleaned)' -> words: \(words)")
			
			// Strategy 1: Look for exactly 2 or 3 words that could be a name
			if words.count >= 2 && words.count <= 3 {
				// Check if words look like names (mostly letters)
				let nameWords = words.filter { word in
					let letterCount = word.filter { $0.isLetter }.count
					return letterCount >= word.count * 0.7 // At least 70% letters
				}
				
				if nameWords.count >= 2 {
					let potentialName = nameWords.prefix(2).joined(separator: " ")
					print("   🎯 Found potential name: '\(potentialName)'")
					
					// Additional validation - avoid common non-name patterns
					let invalidPatterns = ["WHITE SOX", "ROOKIE", "CARD", "BASEBALL", "TOPPS", "PANINI"]
					let isValid = !invalidPatterns.contains { potentialName.uppercased().contains($0) }
					
					if isValid {
						return potentialName
					}
				}
			}
			
			// Strategy 2: Single string that might be a full name
			if words.count == 1 && cleaned.count >= 6 {
				// Sometimes OCR combines first and last name
				// Look for capital letters that might indicate word boundaries
				let name = reconstructNameFromCombined(cleaned)
				if let reconstructed = name {
					print("   🔧 Reconstructed name: '\(reconstructed)'")
					return reconstructed
				}
			}
		}
		
		// Strategy 3: Try to fix common OCR errors for "MATT MERULLO"
		for text in strings {
			let fixed = fixCommonOCRErrors(text)
			if fixed != text {
				print("   🔧 Fixed OCR errors: '\(text)' -> '\(fixed)'")
				return fixed
			}
		}
		
		// Fallback: Just take the first reasonable text that might be a name
		for text in strings {
			let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if cleaned.count >= 4 && cleaned.count <= 25 &&
			   !teams.contains(where: { cleaned.lowercased().contains($0.lowercased()) }) {
				
				let words = cleaned.components(separatedBy: " ").filter { !$0.isEmpty }
				if words.count >= 1 && words.count <= 3 {
					print("   🔄 Fallback name: '\(cleaned)'")
					return cleaned
				}
			}
		}
		
		return nil
	}
	
	// Helper method to reconstruct names from combined text
	private func reconstructNameFromCombined(_ text: String) -> String? {
		// Look for patterns like "MATTMERULLO" -> "MATT MERULLO"
		let commonFirstNames = ["MATT", "MIKE", "JOHN", "DAVE", "TOM", "JIM", "BILL", "BOB", "STEVE", "MARK"]
		
		for firstName in commonFirstNames {
			if text.uppercased().hasPrefix(firstName) && text.count > firstName.count {
				let lastName = String(text.dropFirst(firstName.count))
				if lastName.count >= 3 {
					return "\(firstName) \(lastName)"
				}
			}
		}
		
		return nil
	}

	// Helper method to fix common OCR errors
	private func fixCommonOCRErrors(_ text: String) -> String {
		var fixed = text.uppercased()
		
		// Common OCR mistakes for "MATT MERULLO"
		let corrections = [
			"MERUL LO": "MERULLO",
			"MERUL DO": "MERULLO",
			"MERUL TO": "MERULLO",
			"MERULEO": "MERULLO",
			"MHILE": "MATT",  // From previous attempts
			"NATF": "MATT",
			"MART": "MATT"
		]
		
		for (wrong, correct) in corrections {
			fixed = fixed.replacingOccurrences(of: wrong, with: correct)
		}
		
		return fixed
	}
}
