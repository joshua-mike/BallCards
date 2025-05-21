import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit
import CoreData

class FirebaseManager {
	static let shared = FirebaseManager()
	
	private let db = Firestore.firestore()
	private let storage = Storage.storage().reference()
	
	// Synchronize a card to Firestore
	func syncCard(_ card: Card, completion: @escaping (Error?) -> Void) {
		guard let cardID = card.id?.uuidString else {
			completion(NSError(domain: "SportsCardLog", code: 1, userInfo: [NSLocalizedDescriptionKey: "Card has no ID"]))
			return
		}
		
		// Create document for the card
		var cardData: [String: Any] = [
			"id": cardID,
			"dateAdded": card.dateAdded ?? Date(),
			"playerName": card.playerName ?? "Unknown Player",
			"year": card.year ?? "Unknown Year",
			"team": card.team ?? "Unknown Team",
			"cardNumber": card.cardNumber ?? "",
			"series": card.series ?? "",
			"condition": card.condition ?? "",
			"notes": card.notes ?? ""
		]
		
		// Upload images in parallel group
		let dispatchGroup = DispatchGroup()
		
		// Upload front image if exists
		if let frontImageData = card.frontImage {
			dispatchGroup.enter()
			
			let frontRef = storage.child("cards/\(cardID)/front.jpg")
			frontRef.putData(frontImageData, metadata: nil) { metadata, error in
				if let error = error {
					print("Error uploading front image: \(error)")
					dispatchGroup.leave()
					return
				}
				
				frontRef.downloadURL { url, error in
					if let downloadURL = url {
						cardData["frontImageURL"] = downloadURL.absoluteString
					}
					dispatchGroup.leave()
				}
			}
		}
		
		// Upload back image if exists
		if let backImageData = card.backImage {
			dispatchGroup.enter()
			
			let backRef = storage.child("cards/\(cardID)/back.jpg")
			backRef.putData(backImageData, metadata: nil) { metadata, error in
				if let error = error {
					print("Error uploading back image: \(error)")
					dispatchGroup.leave()
					return
				}
				
				backRef.downloadURL { url, error in
					if let downloadURL = url {
						cardData["backImageURL"] = downloadURL.absoluteString
					}
					dispatchGroup.leave()
				}
			}
		}
		
		// When all uploads are complete, save document to Firestore
		dispatchGroup.notify(queue: .main) {
			self.db.collection("cards").document(cardID).setData(cardData) { error in
				completion(error)
			}
		}
	}
	
	// Fetch all cards from Firestore
	func fetchCards(completion: @escaping ([CardData]?, Error?) -> Void) {
		db.collection("cards").order(by: "dateAdded", descending: true).getDocuments { (snapshot, error) in
			if let error = error {
				completion(nil, error)
				return
			}
			
			guard let documents = snapshot?.documents else {
				completion([], nil)
				return
			}
			
			let cards = documents.compactMap { document -> CardData? in
				do {
					return try document.data(as: CardData.self)
				} catch {
					print("Error decoding card: \(error)")
					return nil
				}
			}
			
			completion(cards, nil)
		}
	}
	
	// Download image from URL
	func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(nil)
			return
		}
		
		URLSession.shared.dataTask(with: url) { data, response, error in
			guard let data = data, error == nil else {
				completion(nil)
				return
			}
			
			let image = UIImage(data: data)
			DispatchQueue.main.async {
				completion(image)
			}
		}.resume()
	}
}
