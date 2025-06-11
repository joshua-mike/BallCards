import Vision
import UIKit
import CoreML

class CardRecognizer {
	static let shared = CardRecognizer()
	
	private init() {
		// Private initializer for singleton
	}
	
	// Extract text from image and identify card details
	func extractCardInfo(from image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		// Ensure we're not on the main thread for processing
		DispatchQueue.global(qos: .userInitiated).async {
			self.performTextRecognition(on: image, completion: completion)
		}
	}
	
	private func performTextRecognition(on image: UIImage, completion: @escaping ([String: String]?) -> Void) {
		// Resize image if it's too large (helps with performance and cache issues)
		let resizedImage = resizeImageIfNeeded(image)
		
		guard let cgImage = resizedImage.cgImage else {
			DispatchQueue.main.async {
				completion(nil)
			}
			return
		}
		
		// Create a new request for each recognition to avoid state issues
		let request = VNRecognizeTextRequest { [weak self] (request, error) in
			if let error = error {
				print("Vision text recognition error: \(error.localizedDescription)")
				DispatchQueue.main.async {
					completion(nil)
				}
				return
			}
			
			guard let observations = request.results as? [VNRecognizedTextObservation] else {
				DispatchQueue.main.async {
					completion(nil)
				}
				return
			}
			
			// Process the recognized text
			let recognizedStrings = observations.compactMap { observation in
				observation.topCandidates(1).first?.string
			}
			
			// Extract card information from recognized text
			let cardInfo = self?.parseCardInfo(from: recognizedStrings) ?? [:]
			
			DispatchQueue.main.async {
				completion(cardInfo.isEmpty ? nil : cardInfo)
			}
		}
		
		// Configure the request
		request.recognitionLevel = .accurate
		request.usesLanguageCorrection = true
		request.recognitionLanguages = ["en-US"]
		request.automaticallyDetectsLanguage = false
		
		// Create request handler with specific options to avoid cache issues
		let requestHandler = VNImageRequestHandler(
			cgImage: cgImage,
			orientation: .up,
			options: [
				VNImageOption.ciContext: CIContext(options: [
					.useSoftwareRenderer: false,
					.priorityRequestLow: true
				])
			]
		)
		
		do {
			// Perform the text recognition request
			try requestHandler.perform([request])
		} catch {
			print("Failed to perform Vision request: \(error.localizedDescription)")
			DispatchQueue.main.async {
				completion(nil)
			}
		}
	}
	
	// Resize image if it's too large to prevent memory and cache issues
	private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
		let maxDimension: CGFloat = 1024
		let size = image.size
		
		// If image is already small enough, return as-is
		if size.width <= maxDimension && size.height <= maxDimension {
			return image
		}
		
		// Calculate new size maintaining aspect ratio
		let ratio = min(maxDimension / size.width, maxDimension / size.height)
		let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
		
		// Resize the image
		UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
		defer { UIGraphicsEndImageContext() }
		
		image.draw(in: CGRect(origin: .zero, size: newSize))
		return UIGraphicsGetImageFromCurrentImageContext() ?? image
	}
	
	// Parse recognized text to extract player name, year, team, etc.
	private func parseCardInfo(from strings: [String]) -> [String: String] {
		var cardInfo = [String: String]()
		
		// Join all strings for easier processing
		let allText = strings.joined(separator: " ")
		let lowercaseText = allText.lowercased()
		
		// Enhanced year detection (4-digit number between 1900-2030)
		let yearRegex = try! NSRegularExpression(pattern: #"(?:19|20)\d{2}"#)
		let yearMatches = yearRegex.matches(in: allText, range: NSRange(allText.startIndex..., in: allText))
		
		if let firstMatch = yearMatches.first {
			let yearRange = Range(firstMatch.range, in: allText)!
			cardInfo["year"] = String(allText[yearRange])
		}
		
		// Enhanced team detection with more teams and variations
		let teams = [
			// American League
			"yankees", "red sox", "blue jays", "orioles", "rays",
			"white sox", "guardians", "tigers", "royals", "twins",
			"astros", "angels", "athletics", "mariners", "rangers",
			// National League
			"braves", "marlins", "mets", "phillies", "nationals",
			"cubs", "reds", "brewers", "pirates", "cardinals",
			"diamondbacks", "rockies", "dodgers", "padres", "giants",
			// Common abbreviations
			"nyy", "bos", "tor", "bal", "tb",
			"cws", "cle", "det", "kc", "min",
			"hou", "laa", "oak", "sea", "tex",
			"atl", "mia", "nym", "phi", "wsh",
			"chc", "cin", "mil", "pit", "stl",
			"ari", "col", "lad", "sd", "sf"
		]
		
		for team in teams {
			if lowercaseText.contains(team) {
				// Convert abbreviation to full name if possible
				let fullTeamName = getFullTeamName(for: team)
				cardInfo["team"] = fullTeamName
				break
			}
		}
		
		// Enhanced card number detection
		let cardNumberPatterns = [
			#"#\s*(\d+)"#,           // #123 or # 123
			#"no\.?\s*(\d+)"#,       // No. 123 or No 123
			#"card\s*#?\s*(\d+)"#,   // Card #123 or Card 123
			#"(?:^|\s)(\d{1,4})(?:\s|$)"# // Standalone 1-4 digit numbers
		]
		
		for pattern in cardNumberPatterns {
			let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
			let matches = regex.matches(in: allText, range: NSRange(allText.startIndex..., in: allText))
			
			if let match = matches.first,
			   let numberRange = Range(match.range(at: 1), in: allText) {
				let cardNumber = String(allText[numberRange])
				if let number = Int(cardNumber), number > 0 && number < 10000 {
					cardInfo["cardNumber"] = cardNumber
					break
				}
			}
		}
		
		// Enhanced player name detection
		let potentialNames = extractPotentialPlayerNames(from: strings, excludingTeams: teams)
		if let playerName = potentialNames.first {
			cardInfo["playerName"] = playerName
		}
		
		// Try to detect card series/set
		let commonSeries = [
			"topps", "panini", "upper deck", "bowman", "donruss", "fleer",
			"score", "leaf", "stadium club", "chrome", "finest", "heritage",
			"opening day", "series 1", "series 2", "update", "rookie"
		]
		
		for series in commonSeries {
			if lowercaseText.contains(series) {
				cardInfo["series"] = series.capitalized
				break
			}
		}
		
		return cardInfo
	}
	
	private func extractPotentialPlayerNames(from strings: [String], excludingTeams teams: [String]) -> [String] {
		var potentialNames: [String] = []
		
		for string in strings {
			let words = string.components(separatedBy: .whitespacesAndNewlines)
				.filter { !$0.isEmpty }
			
			// Look for sequences of 2-3 capitalized words that aren't team names
			for i in 0..<words.count {
				if i + 1 < words.count {
					let firstName = words[i]
					let lastName = words[i + 1]
					
					// Check if both words start with capital letters and aren't team names
					if firstName.first?.isUppercase == true &&
					   lastName.first?.isUppercase == true &&
					   !teams.contains(firstName.lowercased()) &&
					   !teams.contains(lastName.lowercased()) &&
					   firstName.count > 1 && lastName.count > 1 {
						
						let fullName = "\(firstName) \(lastName)"
						
						// Additional check: avoid obvious non-names
						if !isLikelyNotAName(fullName) {
							potentialNames.append(fullName)
						}
					}
				}
			}
		}
		
		return potentialNames
	}
	
	private func isLikelyNotAName(_ text: String) -> Bool {
		let nonNameWords = [
			"rookie", "card", "baseball", "topps", "panini", "series",
			"edition", "chrome", "finest", "heritage", "bowman", "upper",
			"deck", "stadium", "club", "opening", "day", "update"
		]
		
		let lowercaseText = text.lowercased()
		return nonNameWords.contains { lowercaseText.contains($0) }
	}
	
	private func getFullTeamName(for abbreviationOrPartial: String) -> String {
		let teamMappings: [String: String] = [
			"nyy": "Yankees", "bos": "Red Sox", "tor": "Blue Jays",
			"bal": "Orioles", "tb": "Rays", "cws": "White Sox",
			"cle": "Guardians", "det": "Tigers", "kc": "Royals",
			"min": "Twins", "hou": "Astros", "laa": "Angels",
			"oak": "Athletics", "sea": "Mariners", "tex": "Rangers",
			"atl": "Braves", "mia": "Marlins", "nym": "Mets",
			"phi": "Phillies", "wsh": "Nationals", "chc": "Cubs",
			"cin": "Reds", "mil": "Brewers", "pit": "Pirates",
			"stl": "Cardinals", "ari": "Diamondbacks", "col": "Rockies",
			"lad": "Dodgers", "sd": "Padres", "sf": "Giants",
			"yankees": "Yankees", "red sox": "Red Sox", "blue jays": "Blue Jays",
			"orioles": "Orioles", "rays": "Rays", "white sox": "White Sox",
			"guardians": "Guardians", "tigers": "Tigers", "royals": "Royals",
			"twins": "Twins", "astros": "Astros", "angels": "Angels",
			"athletics": "Athletics", "mariners": "Mariners", "rangers": "Rangers",
			"braves": "Braves", "marlins": "Marlins", "mets": "Mets",
			"phillies": "Phillies", "nationals": "Nationals", "cubs": "Cubs",
			"reds": "Reds", "brewers": "Brewers", "pirates": "Pirates",
			"cardinals": "Cardinals", "diamondbacks": "Diamondbacks",
			"rockies": "Rockies", "dodgers": "Dodgers", "padres": "Padres",
			"giants": "Giants"
		]
		
		return teamMappings[abbreviationOrPartial.lowercased()] ?? abbreviationOrPartial.capitalized
	}
}
