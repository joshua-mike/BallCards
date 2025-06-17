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
			processingMessage = "Analyzing front of card..."
			
			// Create a new card
			let newCard = Card(context: viewContext)
			newCard.id = UUID()
			newCard.dateAdded = Date()
			newCard.frontImage = image.jpegData(compressionQuality: 0.8)
			
			// Save immediately to avoid losing the image
			do {
				try viewContext.save()
			} catch {
				handleError("Failed to save card image: \(error.localizedDescription)")
				return
			}
			
			// Set as active card
			self.activeCard = newCard
			
			// Use OCR to extract data from the card with timeout protection
			let timeoutWorkItem = DispatchWorkItem {
				DispatchQueue.main.async {
					if self.isProcessing {
						self.isProcessing = false
						self.processingMessage = "Processing card..."
						
						// Continue to back side even if OCR fails
						self.isFrontSide = false
						self.isShowingCamera = true
					}
				}
			}
			
			// Set a 10-second timeout for OCR
			DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
			
			CardRecognizer.shared.extractCardInfo(from: image) { cardInfo in
				// Cancel the timeout since we got a response
				timeoutWorkItem.cancel()
				
				DispatchQueue.main.async {
					if let cardInfo = cardInfo {
						// Update card with extracted information
						newCard.playerName = cardInfo["playerName"] ?? "Unknown Player"
						newCard.year = cardInfo["year"] ?? "Unknown Year"
						newCard.team = cardInfo["team"] ?? "Unknown Team"
						newCard.cardNumber = cardInfo["cardNumber"]
						newCard.series = cardInfo["series"]
						
						// Save the updated card data
						do {
							try viewContext.save()
						} catch {
							print("Error saving card data: \(error)")
						}
					}
					
					// Continue to back side
					self.isProcessing = false
					self.processingMessage = "Processing card..."
					self.isFrontSide = false
					self.isShowingCamera = true
				}
			}
		} else {
			// Processing back side
			isProcessing = true
			processingMessage = "Saving back of card..."
			
			if let card = activeCard {
				card.backImage = image.jpegData(compressionQuality: 0.8)
				
				// Save the updated card
				do {
					try viewContext.save()
				} catch {
					handleError("Failed to save card back: \(error.localizedDescription)")
					return
				}
				
				// Show the edit view after capturing both sides
				DispatchQueue.main.async {
					self.isProcessing = false
					self.processingMessage = "Processing card..."
					self.showingNewCardEdit = true
				}
			} else {
				handleError("Card data was lost during processing")
			}
		}
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
