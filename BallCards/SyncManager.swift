// SyncManager.swift
import Foundation
import CoreData
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class SyncManager {
	static let shared = SyncManager()
	
	private let db = Firestore.firestore()
	private let storage = Storage.storage().reference()
	
	private var syncInProgress = false
	
	// Core Data context
	private var viewContext: NSManagedObjectContext {
		return PersistenceController.shared.container.viewContext
	}
	
	// MARK: - Sync Operations
	
	/// Performs a full sync between local database and Firebase
	func performFullSync(completion: @escaping (Bool, Error?) -> Void) {
		guard !syncInProgress else {
			completion(false, NSError(domain: "BallCards", code: 100, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"]))
			return
		}
		
		guard Auth.auth().currentUser?.uid != nil as String? else {
			completion(false, NSError(domain: "BallCards", code: 101, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
			return
		}
		
		syncInProgress = true
		
		// 1. Push all local changes to Firebase first
		pushLocalChanges { [weak self] success, error in
			guard let self = self else { return }
			
			if let error = error {
				self.syncInProgress = false
				completion(false, error)
				return
			}
			
			// 2. Then pull all remote changes from Firebase
			self.pullRemoteChanges { success, error in
				self.syncInProgress = false
				completion(success, error)
			}
		}
	}
	
	/// Pushes all local changes to Firebase
	private func pushLocalChanges(completion: @escaping (Bool, Error?) -> Void) {
		let fetchRequest: NSFetchRequest<Card> = Card.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "syncStatus != %@ OR syncStatus == nil", "synced")
		
		do {
			let cardsToSync = try viewContext.fetch(fetchRequest)
			
			if cardsToSync.isEmpty {
				completion(true, nil)
				return
			}
			
			let dispatchGroup = DispatchGroup()
			var syncErrors: [Error] = []
			
			for card in cardsToSync {
				dispatchGroup.enter()
				
				uploadCard(card) { success, error in
					if let error = error {
						syncErrors.append(error)
					} else if success {
						// Update card sync status
						card.syncStatus = "synced"
						card.lastSynced = Date()
					}
					
					dispatchGroup.leave()
				}
			}
			
			dispatchGroup.notify(queue: .main) {
				do {
					try self.viewContext.save()
					completion(syncErrors.isEmpty, syncErrors.first)
				} catch {
					completion(false, error)
				}
			}
			
		} catch {
			completion(false, error)
		}
	}
	
	/// Pulls all remote changes from Firebase
	private func pullRemoteChanges(completion: @escaping (Bool, Error?) -> Void) {
		guard let currentUserID = Auth.auth().currentUser?.uid else {
			completion(false, NSError(domain: "SportsCardLog", code: 101, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
			return
		}
		
		// Get all cards from Firebase
		db.collection("cards")
			.whereField("ownerID", isEqualTo: currentUserID)
			.getDocuments { [weak self] snapshot, error in
				guard let self = self else { return }
				
				if let error = error {
					completion(false, error)
					return
				}
				
				guard let documents = snapshot?.documents else {
					completion(true, nil)
					return
				}
				
				let dispatchGroup = DispatchGroup()
				var syncErrors: [Error] = []
				
				for document in documents {
					dispatchGroup.enter()
					
					self.downloadCard(document: document) { success, error in
						if let error = error {
							syncErrors.append(error)
						}
						
						dispatchGroup.leave()
					}
				}
				
				dispatchGroup.notify(queue: .main) {
					do {
						try self.viewContext.save()
						completion(syncErrors.isEmpty, syncErrors.first)
					} catch {
						completion(false, error)
					}
				}
			}
	}
	
	// MARK: - Card Upload/Download
	
	/// Uploads a card to Firebase
	private func uploadCard(_ card: Card, completion: @escaping (Bool, Error?) -> Void) {
		guard let cardID = card.id?.uuidString else {
			completion(false, NSError(domain: "SportsCardLog", code: 102, userInfo: [NSLocalizedDescriptionKey: "Card has no ID"]))
			return
		}
		
		guard let currentUserID = Auth.auth().currentUser?.uid else {
			completion(false, NSError(domain: "SportsCardLog", code: 101, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
			return
		}
		
		// Prepare card data for Firestore
		var cardData: [String: Any] = [
			"id": cardID,
			"ownerID": currentUserID,
			"dateAdded": card.dateAdded ?? Date(),
			"playerName": card.playerName ?? "Unknown Player",
			"year": card.year ?? "Unknown Year",
			"team": card.team ?? "Unknown Team",
			"cardNumber": card.cardNumber ?? "",
			"series": card.series ?? "",
			"manufacturer": card.manufacturer ?? "",
			"position": card.position ?? "",
			"condition": card.condition ?? "",
			"notes": card.notes ?? "",
			"lastSynced": Date()
		]
		
		// If there's an estimated value, add it
		if let estimatedValue = card.estimated_value {
			cardData["estimated_value"] = estimatedValue
		}
		
		// Upload images in parallel
		let dispatchGroup = DispatchGroup()
		
		// Upload front image
		if let frontImageData = card.frontImage {
			dispatchGroup.enter()
			
			let frontRef = storage.child("cards/\(cardID)/front.jpg")
			frontRef.putData(frontImageData, metadata: nil) { metadata, error in
				if let error = error {
					dispatchGroup.leave()
					completion(false, error)
					return
				}
				
				frontRef.downloadURL { url, error in
					defer { dispatchGroup.leave() }
					
					if let error = error {
						completion(false, error)
						return
					}
					
					if let downloadURL = url {
						cardData["frontImageURL"] = downloadURL.absoluteString
					}
				}
			}
		}
		
		// Upload back image
		if let backImageData = card.backImage {
			dispatchGroup.enter()
			
			let backRef = storage.child("cards/\(cardID)/back.jpg")
			backRef.putData(backImageData, metadata: nil) { metadata, error in
				if let error = error {
					dispatchGroup.leave()
					completion(false, error)
					return
				}
				
				backRef.downloadURL { url, error in
					defer { dispatchGroup.leave() }
					
					if let error = error {
						completion(false, error)
						return
					}
					
					if let downloadURL = url {
						cardData["backImageURL"] = downloadURL.absoluteString
					}
				}
			}
		}
		
		// When all uploads complete, save to Firestore
		dispatchGroup.notify(queue: .main) {
			self.db.collection("cards").document(cardID).setData(cardData) { error in
				if let error = error {
					completion(false, error)
				} else {
					completion(true, nil)
				}
			}
		}
	}
	
	/// Downloads a card from Firebase
	private func downloadCard(document: QueryDocumentSnapshot, completion: @escaping (Bool, Error?) -> Void) {
		let data = document.data()
		
		guard let cardID = data["id"] as? String,
			  let uuid = UUID(uuidString: cardID) else {
			completion(false, NSError(domain: "SportsCardLog", code: 103, userInfo: [NSLocalizedDescriptionKey: "Invalid card ID"]))
			return
		}
		
		// Check if card already exists locally
		let fetchRequest: NSFetchRequest<Card> = Card.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
		
		do {
			let existingCards = try viewContext.fetch(fetchRequest)
			
			let card: Card
			
			if let existingCard = existingCards.first {
				// Card exists, update it
				card = existingCard
				
				// Check if local card is newer than remote
				if let lastSynced = card.lastSynced,
				   let remoteLastSynced = (data["lastSynced"] as? Timestamp)?.dateValue(),
				   lastSynced > remoteLastSynced {
					// Local card is newer, skip update
					completion(true, nil)
					return
				}
			} else {
				// Create new card
				card = Card(context: viewContext)
				card.id = uuid
				card.dateAdded = (data["dateAdded"] as? Timestamp)?.dateValue() ?? Date()
			}
			
			// Update card data
			card.playerName = data["playerName"] as? String
			card.year = data["year"] as? String
			card.team = data["team"] as? String
			card.cardNumber = data["cardNumber"] as? String
			card.series = data["series"] as? String
			card.manufacturer = data["manufacturer"] as? String
			card.position = data["position"] as? String
			card.condition = data["condition"] as? String
			card.notes = data["notes"] as? String
			
			if let estimatedValue = data["estimated_value"] as? NSNumber {
				card.estimated_value = estimatedValue.decimalValue as NSDecimalNumber
			}
			
			// Set sync status
			card.syncStatus = "synced"
			card.lastSynced = (data["lastSynced"] as? Timestamp)?.dateValue() ?? Date()
			
			// Download images
			let dispatchGroup = DispatchGroup()
			
			// Download front image
			if let frontImageURL = data["frontImageURL"] as? String {
				dispatchGroup.enter()
				
				downloadImage(from: frontImageURL) { imageData in
					if let imageData = imageData {
						card.frontImage = imageData
					}
					dispatchGroup.leave()
				}
			}
			
			// Download back image
			if let backImageURL = data["backImageURL"] as? String {
				dispatchGroup.enter()
				
				downloadImage(from: backImageURL) { imageData in
					if let imageData = imageData {
						card.backImage = imageData
					}
					dispatchGroup.leave()
				}
			}
			
			dispatchGroup.notify(queue: .main) {
				completion(true, nil)
			}
			
		} catch {
			completion(false, error)
		}
	}
	
	/// Downloads an image from a URL
	private func downloadImage(from urlString: String, completion: @escaping (Data?) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(nil)
			return
		}
		
		URLSession.shared.dataTask(with: url) { data, response, error in
			completion(data)
		}.resume()
	}
	
	// MARK: - Family Sharing
	
	/// Gets all cards shared by family members
	func getFamilySharedCards(completion: @escaping ([Card]?, Error?) -> Void) {
		guard let currentUserID = Auth.auth().currentUser?.uid else {
			completion(nil, NSError(domain: "SportsCardLog", code: 101, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
			return
		}
		
		// Get user's family group
		db.collection("families").whereField("members", arrayContains: currentUserID)
			.getDocuments { [weak self] snapshot, error in
				guard let self = self else { return }
				
				if let error = error {
					completion(nil, error)
					return
				}
				
				if let familyDoc = snapshot?.documents.first {
					let familyData = familyDoc.data()
					
					// Get all members except current user
					if let members = familyData["members"] as? [String] {
						let otherMembers = members.filter { $0 != currentUserID }
						
						// Get cards from other family members
						self.db.collection("cards")
							.whereField("ownerID", in: otherMembers)
							.getDocuments { snapshot, error in
								if let error = error {
									completion(nil, error)
									return
								}
								
								guard let documents = snapshot?.documents else {
									completion([], nil)
									return
								}
								
								// Process all cards
								let dispatchGroup = DispatchGroup()
								var familyCards: [Card] = []
								
								for document in documents {
									dispatchGroup.enter()
									
									self.downloadCard(document: document) { success, error in
										if success, let card = self.getCardByID(document.data()["id"] as? String) {
											familyCards.append(card)
										}
										dispatchGroup.leave()
									}
								}
								
								dispatchGroup.notify(queue: .main) {
									completion(familyCards, nil)
								}
							}
					} else {
						completion([], nil)
					}
				} else {
					// No family group found
					completion([], nil)
				}
			}
	}
	
	// MARK: - Helper Methods
	
	/// Gets a card by ID
	private func getCardByID(_ idString: String?) -> Card? {
		guard let idString = idString,
			  let uuid = UUID(uuidString: idString) else {
			return nil
		}
		
		let fetchRequest: NSFetchRequest<Card> = Card.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
		
		do {
			let cards = try viewContext.fetch(fetchRequest)
			return cards.first
		} catch {
			print("Error fetching card: \(error)")
			return nil
		}
	}
}
