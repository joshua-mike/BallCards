import SwiftUI
import CoreData
import Vision

struct ContentView: View {
	@State private var isShowingCamera = false
	@State private var cardImage: UIImage?
	@State private var isFrontSide = true
	@State private var activeCard: Card?
	@State private var isProcessing = false
	@State private var processingMessage = "Processing card..."
	@State private var showingNewCardEdit = false
	@State private var showingCardDetail = false
	@State private var searchText = ""
	@State private var sortOption = SortOption.dateAdded
	@State private var filterTeam: String?
	@State private var showingError = false
	@State private var errorMessage = ""
	
	@Environment(\.managedObjectContext) private var viewContext
	
	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \Card.dateAdded, ascending: false)],
		animation: .default)
	private var cards: FetchedResults<Card>
	
	enum SortOption: String, CaseIterable, Identifiable {
		case dateAdded = "Date Added"
		case playerName = "Player Name"
		case year = "Year"
		case team = "Team"
		
		var id: String { self.rawValue }
	}
	
	// Computed property for filtered and sorted cards
	private var filteredCards: [Card] {
		let filtered = cards.filter { card in
			if searchText.isEmpty { return true }
			
			let playerName = card.playerName?.lowercased() ?? ""
			let team = card.team?.lowercased() ?? ""
			let year = card.year ?? ""
			
			return playerName.contains(searchText.lowercased()) ||
				   team.contains(searchText.lowercased()) ||
				   year.contains(searchText)
		}
		
		// Apply team filter if selected
		let teamFiltered = filterTeam == nil ? filtered : filtered.filter { $0.team == filterTeam }
		
		// Sort the results
		return teamFiltered.sorted { first, second in
			switch sortOption {
			case .dateAdded:
				return (first.dateAdded ?? Date()) > (second.dateAdded ?? Date())
			case .playerName:
				return (first.playerName ?? "") < (second.playerName ?? "")
			case .year:
				return (first.year ?? "") > (second.year ?? "")
			case .team:
				return (first.team ?? "") < (second.team ?? "")
			}
		}
	}
	
	// Get all unique teams
	private var uniqueTeams: [String] {
		var teams = Set<String>()
		for card in cards where card.team != nil && !card.team!.isEmpty {
			teams.insert(card.team!)
		}
		return Array(teams).sorted()
	}
	
	var body: some View {
		NavigationView {
			VStack {
				// Search and filter bar
				HStack {
					Image(systemName: "magnifyingglass")
						.foregroundColor(.secondary)
					
					TextField("Search cards", text: $searchText)
						.textFieldStyle(RoundedBorderTextFieldStyle())
					
					Menu {
						// Sort options
						Section(header: Text("Sort By")) {
							ForEach(SortOption.allCases) { option in
								Button(action: {
									sortOption = option
								}) {
									HStack {
										Text(option.rawValue)
										if sortOption == option {
											Image(systemName: "checkmark")
										}
									}
								}
							}
						}
						
						// Team filter options
						Section(header: Text("Filter by Team")) {
							Button(action: {
								filterTeam = nil
							}) {
								HStack {
									Text("All Teams")
									if filterTeam == nil {
										Image(systemName: "checkmark")
									}
								}
							}
							
							ForEach(uniqueTeams, id: \.self) { team in
								Button(action: {
									filterTeam = team
								}) {
									HStack {
										Text(team)
										if filterTeam == team {
											Image(systemName: "checkmark")
										}
									}
								}
							}
						}
					} label: {
						Image(systemName: "line.3.horizontal.decrease.circle")
							.foregroundColor(.blue)
							.imageScale(.large)
					}
				}
				.padding(.horizontal)
				
				if filteredCards.isEmpty {
					VStack(spacing: 20) {
						Image(systemName: "baseball")
							.font(.system(size: 64))
							.foregroundColor(.blue)
						
						Text(cards.isEmpty ? "No cards yet" : "No matching cards")
							.font(.title)
						
						Text(cards.isEmpty ? "Add your first baseball card by tapping the + button" : "Try adjusting your search or filters")
							.multilineTextAlignment(.center)
							.padding()
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					List {
						ForEach(filteredCards, id: \.id) { card in
							CardRow(card: card)
								.contentShape(Rectangle())
								.onTapGesture {
									activeCard = card
									showingCardDetail = true
								}
						}
						.onDelete(perform: deleteItems)
					}
				}
			}
			.navigationTitle("BallCards")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: {
						self.isShowingCamera = true
						self.isFrontSide = true
					}) {
						Label("Add Card", systemImage: "plus")
					}
				}
			}
			.sheet(isPresented: $isShowingCamera) {
				CameraView(image: $cardImage, isFrontSide: $isFrontSide) { image in
					if let image = image {
						processCardImage(image)
					}
				}
			}
			.sheet(isPresented: $showingCardDetail) {
				if let card = activeCard {
					CardDetailView(card: card)
				}
			}
			.sheet(isPresented: $showingNewCardEdit) {
				if let card = activeCard {
					NavigationView {
						CardEditView(card: card)
					}
				}
			}
			.overlay(
				Group {
					if isProcessing {
						VStack(spacing: 20) {
							ProgressView()
								.scaleEffect(1.5)
							
							Text(processingMessage)
								.font(.headline)
								.foregroundColor(.primary)
						}
						.padding(30)
						.background(Color(.systemBackground))
						.cornerRadius(15)
						.shadow(radius: 10)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(Color.black.opacity(0.3))
						.edgesIgnoringSafeArea(.all)
					}
				}
			)
			.alert("Error", isPresented: $showingError) {
				Button("OK") {
					errorMessage = ""
				}
			} message: {
				Text(errorMessage)
			}
		}
	}
	
	private func processCardImage(_ image: UIImage) {
		if isFrontSide {
			// Start processing front side
			isProcessing = true
			processingMessage = "Analyzing and cropping front of card..."
			
			print("🚀 ContentView: Starting to process front image, size: \(image.size)")
			
			// Create a new card
			let newCard = Card(context: viewContext)
			newCard.id = UUID()
			newCard.dateAdded = Date()
			
			// Set as active card
			self.activeCard = newCard
			
			// First attempt: Try advanced cropping
			CardRecognizer.shared.extractCardInfo(from: image, autoCrop: true) { cardInfo, croppedImage in
				DispatchQueue.main.async {
					let finalImage = croppedImage ?? image
					
					// Save the image (cropped or original)
					newCard.frontImage = finalImage.jpegData(compressionQuality: 0.8)
					
					// Check if we got any meaningful data
					let hasGoodData = cardInfo?["playerName"] != nil ||
									 cardInfo?["year"] != nil ||
									 cardInfo?["team"] != nil
					
					if !hasGoodData {
						print("⚠️ ContentView: First attempt didn't get good data, trying fallback...")
						
						// Fallback: Try simple cropping
						CardCropper.shared.simpleCropCard(from: image) { simpleCroppedImage in
							DispatchQueue.main.async {
								if let betterImage = simpleCroppedImage {
									print("🔄 ContentView: Trying OCR again with simple crop...")
									newCard.frontImage = betterImage.jpegData(compressionQuality: 0.8)
									
									// Try OCR again without auto-crop since we manually cropped
									CardRecognizer.shared.extractCardInfo(from: betterImage, autoCrop: false) { fallbackCardInfo, _ in
										DispatchQueue.main.async {
											self.applyCardData(to: newCard, from: fallbackCardInfo)
											self.continueToBackSide()
										}
									}
								} else {
									// Use original image if everything fails
									print("⚠️ ContentView: All cropping failed, using original image")
									newCard.frontImage = image.jpegData(compressionQuality: 0.8)
									self.applyCardData(to: newCard, from: cardInfo)
									self.continueToBackSide()
								}
							}
						}
					} else {
						print("✅ ContentView: Got good data from first attempt")
						self.applyCardData(to: newCard, from: cardInfo)
						self.continueToBackSide()
					}
				}
			}
		} else {
			// Processing back side
			isProcessing = true
			processingMessage = "Cropping and saving back of card..."
			
			print("🚀 ContentView: Starting to process back image")
			
			if let card = activeCard {
				// Try to crop the back image
				CardCropper.shared.detectAndCropCard(from: image) { croppedImage in
					DispatchQueue.main.async {
						let finalImage = croppedImage ?? image
						card.backImage = finalImage.jpegData(compressionQuality: 0.8)
						
						// Save the updated card
						do {
							try viewContext.save()
							print("✅ ContentView: Successfully saved card with back image")
						} catch {
							self.handleError("Failed to save card back: \(error.localizedDescription)")
							return
						}
						
						// Show the edit view after capturing both sides
						self.isProcessing = false
						self.processingMessage = "Processing card..."
						self.showingNewCardEdit = true
					}
				}
			} else {
				handleError("Card data was lost during processing")
			}
		}
	}

	// Helper method to apply card data
	private func applyCardData(to card: Card, from cardInfo: [String: String]?) {
		if let cardInfo = cardInfo {
			card.playerName = cardInfo["playerName"] ?? "Unknown Player"
			card.year = cardInfo["year"] ?? "Unknown Year"
			card.team = cardInfo["team"] ?? "Unknown Team"
			card.cardNumber = cardInfo["cardNumber"]
			card.series = cardInfo["series"]
			card.manufacturer = cardInfo["manufacturer"]
			
			print("✅ ContentView: Applied card data - Name: \(card.playerName ?? "nil"), Year: \(card.year ?? "nil"), Team: \(card.team ?? "nil")")
		} else {
			print("⚠️ ContentView: No card info to apply")
		}
		
		// Save the card data
		do {
			try viewContext.save()
		} catch {
			print("❌ ContentView: Error saving card data: \(error)")
		}
	}

	// Helper method to continue to back side
	private func continueToBackSide() {
		self.isProcessing = false
		self.processingMessage = "Processing card..."
		self.isFrontSide = false
		self.isShowingCamera = true
	}
	
	private func handleError(_ message: String) {
		DispatchQueue.main.async {
			self.isProcessing = false
			self.processingMessage = "Processing card..."
			self.errorMessage = message
			self.showingError = true
		}
	}
	
	private func deleteItems(offsets: IndexSet) {
		withAnimation {
			offsets.map { filteredCards[$0] }.forEach(viewContext.delete)
			
			do {
				try viewContext.save()
			} catch {
				handleError("Failed to delete card: \(error.localizedDescription)")
			}
		}
	}
	
}

struct CardRow: View {
	@ObservedObject var card: Card
	
	var body: some View {
		HStack(spacing: 15) {
			// Card thumbnail
			if let imageData = card.frontImage, let uiImage = UIImage(data: imageData) {
				Image(uiImage: uiImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 60, height: 90)
					.cornerRadius(4)
					.shadow(radius: 1)
			} else {
				RoundedRectangle(cornerRadius: 4)
					.fill(Color.gray.opacity(0.3))
					.frame(width: 60, height: 90)
					.overlay(
						Image(systemName: "baseball")
							.foregroundColor(.gray)
					)
			}
			
			// Card information
			VStack(alignment: .leading, spacing: 4) {
				Text(card.playerName ?? "Unknown Player")
					.font(.headline)
				
				HStack {
					if let year = card.year, !year.isEmpty {
						Text(year)
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					
					if let team = card.team, !team.isEmpty {
						if let year = card.year, !year.isEmpty {
							Text("•")
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
						
						Text(team)
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
				}
				
				if let cardNumber = card.cardNumber, !cardNumber.isEmpty {
					Text("Card #\(cardNumber)")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Spacer()
			
			// Action indicator
			Image(systemName: "chevron.right")
				.foregroundColor(.secondary)
				.font(.caption)
		}
		.padding(.vertical, 8)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		let persistenceController = PersistenceController.preview
		
		// Add some sample data
		let context = persistenceController.container.viewContext
		for i in 0..<5 {
			let newCard = Card(context: context)
			newCard.id = UUID()
			newCard.dateAdded = Date()
			newCard.playerName = "Player \(i+1)"
			newCard.year = "202\(i)"
			newCard.team = ["Yankees", "Red Sox", "Cubs", "Dodgers", "Cardinals"][i % 5]
			newCard.cardNumber = "\(i*10 + 1)"
		}
		
		do {
			try context.save()
		} catch {
			let nsError = error as NSError
			fatalError("Failed to save preview context: \(nsError)")
		}
		
		return ContentView()
			.environment(\.managedObjectContext, persistenceController.container.viewContext)
	}
}
