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
	@State private var showingQuickEdit = false
	
	// Manual crop states
	@State private var showingManualCrop = false
	@State private var imageToManualCrop: UIImage?
	
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
	
	var body: some View {
		BaseView()
			.environmentObject(ViewState(
				isShowingCamera: $isShowingCamera,
				cardImage: $cardImage,
				isFrontSide: $isFrontSide,
				activeCard: $activeCard,
				isProcessing: $isProcessing,
				processingMessage: $processingMessage,
				showingNewCardEdit: $showingNewCardEdit,
				showingCardDetail: $showingCardDetail,
				searchText: $searchText,
				sortOption: $sortOption,
				filterTeam: $filterTeam,
				showingError: $showingError,
				errorMessage: $errorMessage,
				showingQuickEdit: $showingQuickEdit,
				showingManualCrop: $showingManualCrop,
				imageToManualCrop: $imageToManualCrop,
				cards: cards,
				viewContext: viewContext,
				processCardImage: processCardImage,
				deleteItems: deleteItems,
				handleError: handleError
			))
	}
	
	// MARK: - Business Logic (kept here since it uses @Environment)
	
	private func processCardImage(_ image: UIImage) {
		if isFrontSide {
			// Start processing front side
			isProcessing = true
			processingMessage = "Processing front of card..."
			
			print("🚀 ContentView: Starting to process front image")
			
			// Create a new card
			let newCard = Card(context: viewContext)
			newCard.id = UUID()
			newCard.dateAdded = Date()
			newCard.frontImage = image.jpegData(compressionQuality: 0.8)
			
			// Set as active card
			self.activeCard = newCard
			
			// Run OCR on the manually cropped image
			CardRecognizer.shared.extractCardInfo(from: image, autoCrop: false) { cardInfo, _ in
				DispatchQueue.main.async {
					// Apply any OCR results we got
					if let cardInfo = cardInfo {
						newCard.playerName = cardInfo["playerName"] ?? "Unknown Player"
						newCard.year = cardInfo["year"] ?? ""
						newCard.team = cardInfo["team"] ?? ""
						newCard.cardNumber = cardInfo["cardNumber"]
						newCard.manufacturer = cardInfo["manufacturer"]
					}
					
					// Save immediately
					do {
						try viewContext.save()
						print("✅ ContentView: Front side saved")
					} catch {
						print("❌ ContentView: Error saving front: \(error)")
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
			processingMessage = "Processing back of card..."
			
			print("🚀 ContentView: Processing back image")
			
			if let card = activeCard {
				card.backImage = image.jpegData(compressionQuality: 0.8)
				
				// Save the card
				do {
					try viewContext.save()
					print("✅ ContentView: Back side saved")
				} catch {
					self.handleError("Failed to save card: \(error.localizedDescription)")
					return
				}
				
				// Go to quick edit
				self.isProcessing = false
				self.processingMessage = "Processing card..."
				self.showingQuickEdit = true
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
		// Get filtered cards for deletion
		let filteredCards = getFilteredCards()
		
		withAnimation {
			offsets.map { filteredCards[$0] }.forEach(viewContext.delete)
			
			do {
				try viewContext.save()
			} catch {
				handleError("Failed to delete card: \(error.localizedDescription)")
			}
		}
	}
	
	// Helper to get filtered cards (duplicated from the computed property)
	private func getFilteredCards() -> [Card] {
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
}

// MARK: - ViewState ObservableObject

class ViewState: ObservableObject {
	@Binding var isShowingCamera: Bool
	@Binding var cardImage: UIImage?
	@Binding var isFrontSide: Bool
	@Binding var activeCard: Card?
	@Binding var isProcessing: Bool
	@Binding var processingMessage: String
	@Binding var showingNewCardEdit: Bool
	@Binding var showingCardDetail: Bool
	@Binding var searchText: String
	@Binding var sortOption: ContentView.SortOption
	@Binding var filterTeam: String?
	@Binding var showingError: Bool
	@Binding var errorMessage: String
	@Binding var showingQuickEdit: Bool
	@Binding var showingManualCrop: Bool
	@Binding var imageToManualCrop: UIImage?
	
	let cards: FetchedResults<Card>
	let viewContext: NSManagedObjectContext
	let processCardImage: (UIImage) -> Void
	let deleteItems: (IndexSet) -> Void
	let handleError: (String) -> Void
	
	init(
		isShowingCamera: Binding<Bool>,
		cardImage: Binding<UIImage?>,
		isFrontSide: Binding<Bool>,
		activeCard: Binding<Card?>,
		isProcessing: Binding<Bool>,
		processingMessage: Binding<String>,
		showingNewCardEdit: Binding<Bool>,
		showingCardDetail: Binding<Bool>,
		searchText: Binding<String>,
		sortOption: Binding<ContentView.SortOption>,
		filterTeam: Binding<String?>,
		showingError: Binding<Bool>,
		errorMessage: Binding<String>,
		showingQuickEdit: Binding<Bool>,
		showingManualCrop: Binding<Bool>,
		imageToManualCrop: Binding<UIImage?>,
		cards: FetchedResults<Card>,
		viewContext: NSManagedObjectContext,
		processCardImage: @escaping (UIImage) -> Void,
		deleteItems: @escaping (IndexSet) -> Void,
		handleError: @escaping (String) -> Void
	) {
		self._isShowingCamera = isShowingCamera
		self._cardImage = cardImage
		self._isFrontSide = isFrontSide
		self._activeCard = activeCard
		self._isProcessing = isProcessing
		self._processingMessage = processingMessage
		self._showingNewCardEdit = showingNewCardEdit
		self._showingCardDetail = showingCardDetail
		self._searchText = searchText
		self._sortOption = sortOption
		self._filterTeam = filterTeam
		self._showingError = showingError
		self._errorMessage = errorMessage
		self._showingQuickEdit = showingQuickEdit
		self._showingManualCrop = showingManualCrop
		self._imageToManualCrop = imageToManualCrop
		self.cards = cards
		self.viewContext = viewContext
		self.processCardImage = processCardImage
		self.deleteItems = deleteItems
		self.handleError = handleError
	}
	
	// Computed property for filtered cards
	var filteredCards: [Card] {
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
	var uniqueTeams: [String] {
		var teams = Set<String>()
		for card in cards where card.team != nil && !card.team!.isEmpty {
			teams.insert(card.team!)
		}
		return Array(teams).sorted()
	}
}

// MARK: - BaseView (The actual UI)

struct BaseView: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		NavigationView {
			VStack {
				SearchAndFilterBar()
				
				if state.filteredCards.isEmpty {
					EmptyStateView()
				} else {
					CardsList()
				}
			}
			.navigationTitle("BallCards")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: {
						state.isShowingCamera = true
						state.isFrontSide = true
					}) {
						Label("Add Card", systemImage: "plus")
					}
				}
			}
		}
		.overlay(ProcessingOverlay())
		.modifier(AllSheetsModifier())
	}
}

// MARK: - Component Views

struct SearchAndFilterBar: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		HStack {
			Image(systemName: "magnifyingglass")
				.foregroundColor(.secondary)
			
			TextField("Search cards", text: state.$searchText)
				.textFieldStyle(RoundedBorderTextFieldStyle())
			
			Menu {
				SortSection()
				TeamFilterSection()
			} label: {
				Image(systemName: "line.3.horizontal.decrease.circle")
					.foregroundColor(.blue)
					.imageScale(.large)
			}
		}
		.padding(.horizontal)
	}
}

struct SortSection: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Section(header: Text("Sort By")) {
			ForEach(ContentView.SortOption.allCases) { option in
				Button(action: {
					state.sortOption = option
				}) {
					HStack {
						Text(option.rawValue)
						if state.sortOption == option {
							Image(systemName: "checkmark")
						}
					}
				}
			}
		}
	}
}

struct TeamFilterSection: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Section(header: Text("Filter by Team")) {
			Button(action: {
				state.filterTeam = nil
			}) {
				HStack {
					Text("All Teams")
					if state.filterTeam == nil {
						Image(systemName: "checkmark")
					}
				}
			}
			
			ForEach(state.uniqueTeams, id: \.self) { team in
				Button(action: {
					state.filterTeam = team
				}) {
					HStack {
						Text(team)
						if state.filterTeam == team {
							Image(systemName: "checkmark")
						}
					}
				}
			}
		}
	}
}

struct EmptyStateView: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "baseball")
				.font(.system(size: 64))
				.foregroundColor(.blue)
			
			Text(state.cards.isEmpty ? "No cards yet" : "No matching cards")
				.font(.title)
			
			Text(state.cards.isEmpty ? "Add your first baseball card by tapping the + button" : "Try adjusting your search or filters")
				.multilineTextAlignment(.center)
				.padding()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

struct CardsList: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		List {
			ForEach(state.filteredCards, id: \.id) { card in
				CardRow(card: card)
					.contentShape(Rectangle())
					.onTapGesture {
						state.activeCard = card
						state.showingCardDetail = true
					}
			}
			.onDelete(perform: state.deleteItems)
		}
	}
}

struct ProcessingOverlay: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Group {
			if state.isProcessing {
				VStack(spacing: 20) {
					ProgressView()
						.scaleEffect(1.5)
					
					Text(state.processingMessage)
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
	}
}

// MARK: - All Sheets Modifier

struct AllSheetsModifier: ViewModifier {
	@EnvironmentObject var state: ViewState
	
	func body(content: Content) -> some View {
		content
			.sheet(isPresented: state.$showingQuickEdit) {
				QuickEditSheet()
			}
			.sheet(isPresented: state.$isShowingCamera) {
				CameraSheet()
			}
			.onChange(of: state.isShowingCamera) {
				handleCameraChange(state.isShowingCamera)
			}
			.fullScreenCover(isPresented: state.$showingManualCrop) {
				state.imageToManualCrop = nil
			} content: {
				ManualCropSheet()
			}
			.sheet(isPresented: state.$showingCardDetail) {
				CardDetailSheet()
			}
			.sheet(isPresented: state.$showingNewCardEdit) {
				NewCardEditSheet()
			}
			.alert("Error", isPresented: state.$showingError) {
				Button("OK") {
					state.errorMessage = ""
				}
			} message: {
				Text(state.errorMessage)
			}
	}
	
	private func handleCameraChange(_ isShowing: Bool) {
		if !isShowing && state.imageToManualCrop != nil {
			print("📱 Camera dismissed, showing manual crop")
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				state.showingManualCrop = true
			}
		}
	}
}

// MARK: - Sheet Views

struct QuickEditSheet: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Group {
			if let card = state.activeCard {
				QuickEditCardView(card: card)
			}
		}
	}
}

struct CameraSheet: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		CameraView(image: state.$cardImage, isFrontSide: state.$isFrontSide) { image in
			if let image = image {
				print("📷 Captured image, size: \(image.size)")
				state.imageToManualCrop = image
				state.isShowingCamera = false
			}
		}
	}
}

struct ManualCropSheet: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Group {
			if let image = state.imageToManualCrop {
				ManualCropView(
					image: image,
					onCropComplete: { croppedImage in
						print("✅ Manual crop completed")
						state.showingManualCrop = false
						
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
							state.processCardImage(croppedImage ?? image)
						}
					},
					onCancel: {
						print("❌ Manual crop cancelled")
						state.showingManualCrop = false
						
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
							state.isShowingCamera = true
						}
					}
				)
			} else {
				ErrorFallbackView()
			}
		}
	}
}

struct ErrorFallbackView: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		VStack(spacing: 20) {
			Text("Error loading image")
				.foregroundColor(.white)
				.font(.title2)
			
			Text("Please try taking the photo again")
				.foregroundColor(.white.opacity(0.8))
			
			Button("Close") {
				state.showingManualCrop = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					state.isShowingCamera = true
				}
			}
			.foregroundColor(.black)
			.padding(.horizontal, 24)
			.padding(.vertical, 12)
			.background(Color.white)
			.cornerRadius(8)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black)
	}
}

struct CardDetailSheet: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Group {
			if let card = state.activeCard {
				CardDetailView(card: card)
			}
		}
	}
}

struct NewCardEditSheet: View {
	@EnvironmentObject var state: ViewState
	
	var body: some View {
		Group {
			if let card = state.activeCard {
				NavigationView {
					CardEditView(card: card)
				}
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
