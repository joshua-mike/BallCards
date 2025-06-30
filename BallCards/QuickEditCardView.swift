// QuickEditCardView.swift - Fast entry for essential card info
import SwiftUI
import CoreData

struct QuickEditCardView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@Environment(\.presentationMode) var presentationMode
	
	@ObservedObject var card: Card
	
	// Essential fields only - focus on speed
	@State private var playerName: String
	@State private var year: String
	@State private var team: String
	@State private var cardNumber: String
	
	@State private var showingFullEdit = false
	
	// Common teams for quick selection
	private let commonTeams = [
		"Yankees", "Red Sox", "Cubs", "Dodgers", "Cardinals", "Giants",
		"Braves", "Astros", "Mets", "Phillies", "Angels", "Blue Jays",
		"White Sox", "Brewers", "Athletics", "Padres", "Royals", "Marlins",
		"Pirates", "Rangers", "Mariners", "Rays", "Nationals", "Tigers",
		"Rockies", "Orioles", "Diamondbacks", "Twins", "Guardians", "Reds"
	]
	
	// Current decade years for quick selection
	private var recentYears: [String] {
		let currentYear = Calendar.current.component(.year, from: Date())
		return (currentYear-20...currentYear).map { String($0) }.reversed()
	}
	
	init(card: Card) {
		self.card = card
		_playerName = State(initialValue: card.playerName ?? "")
		_year = State(initialValue: card.year ?? "")
		_team = State(initialValue: card.team ?? "")
		_cardNumber = State(initialValue: card.cardNumber ?? "")
	}
	
	var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: 20) {
					// Card preview at top
					HStack(spacing: 15) {
						if let frontImageData = card.frontImage,
						   let frontImage = UIImage(data: frontImageData) {
							Image(uiImage: frontImage)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(height: 100)
								.cornerRadius(8)
						}
						
						if let backImageData = card.backImage,
						   let backImage = UIImage(data: backImageData) {
							Image(uiImage: backImage)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(height: 100)
								.cornerRadius(8)
						}
					}
					.padding(.horizontal)
					
					VStack(spacing: 20) {
						// Player Name
						VStack(alignment: .leading, spacing: 8) {
							Text("Player Name")
								.font(.headline)
								.foregroundColor(.primary)
							
							TextField("Enter player name", text: $playerName)
								.textFieldStyle(RoundedBorderTextFieldStyle())
								.autocapitalization(.words)
								.font(.body)
						}
						
						// Year with quick buttons
						VStack(alignment: .leading, spacing: 8) {
							Text("Year")
								.font(.headline)
								.foregroundColor(.primary)
							
							TextField("Year", text: $year)
								.textFieldStyle(RoundedBorderTextFieldStyle())
								.keyboardType(.numberPad)
								.font(.body)
							
							// Quick year buttons
							ScrollView(.horizontal, showsIndicators: false) {
								HStack(spacing: 8) {
									ForEach(recentYears.prefix(10), id: \.self) { yearOption in
										Button(yearOption) {
											year = yearOption
										}
										.buttonStyle(.bordered)
										.controlSize(.small)
									}
								}
								.padding(.horizontal, 4)
							}
						}
						
						// Team with quick selection
						VStack(alignment: .leading, spacing: 8) {
							Text("Team")
								.font(.headline)
								.foregroundColor(.primary)
							
							TextField("Team name", text: $team)
								.textFieldStyle(RoundedBorderTextFieldStyle())
								.autocapitalization(.words)
								.font(.body)
							
							// Quick team buttons (most common)
							LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
								ForEach(commonTeams.prefix(12), id: \.self) { teamOption in
									Button(teamOption) {
										team = teamOption
									}
									.buttonStyle(.bordered)
									.controlSize(.small)
									.font(.caption)
								}
							}
						}
						
						// Card Number
						VStack(alignment: .leading, spacing: 8) {
							Text("Card Number (Optional)")
								.font(.headline)
								.foregroundColor(.primary)
							
							TextField("Card #", text: $cardNumber)
								.textFieldStyle(RoundedBorderTextFieldStyle())
								.keyboardType(.numberPad)
								.font(.body)
						}
						
						// Action buttons
						VStack(spacing: 12) {
							// Primary action - Save & Continue
							Button(action: {
								saveQuickInfo()
								presentationMode.wrappedValue.dismiss()
							}) {
								HStack {
									Image(systemName: "checkmark.circle.fill")
									Text("Save & Continue")
										.fontWeight(.semibold)
								}
								.frame(maxWidth: .infinity)
								.padding(.vertical, 12)
								.background(Color.blue)
								.foregroundColor(.white)
								.cornerRadius(10)
							}
							
							// Secondary action - More Details
							Button(action: {
								saveQuickInfo()
								showingFullEdit = true
							}) {
								HStack {
									Image(systemName: "ellipsis.circle")
									Text("Add More Details")
										.fontWeight(.medium)
								}
								.frame(maxWidth: .infinity)
								.padding(.vertical, 12)
								.background(Color.secondary.opacity(0.2))
								.foregroundColor(.primary)
								.cornerRadius(10)
							}
						}
						.padding(.top, 10)
					}
					.padding(.horizontal)
				}
			}
			.navigationTitle("Quick Edit")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("Cancel") {
						presentationMode.wrappedValue.dismiss()
					}
				}
			}
		}
		.sheet(isPresented: $showingFullEdit) {
			NavigationView {
				CardEditView(card: card)
			}
		}
	}
	
	private func saveQuickInfo() {
		// Save essential info
		card.playerName = playerName.isEmpty ? "Unknown Player" : playerName
		card.year = year.isEmpty ? "" : year
		card.team = team.isEmpty ? "" : team
		card.cardNumber = cardNumber.isEmpty ? nil : cardNumber
		
		// Mark as needing sync
		card.syncStatus = "pendingUpload"
		
		do {
			try viewContext.save()
			print("✅ Quick card info saved")
		} catch {
			print("❌ Error saving quick card info: \(error)")
		}
	}
}

struct QuickEditCardView_Previews: PreviewProvider {
	static var previews: some View {
		let context = PersistenceController.preview.container.viewContext
		let sampleCard = Card(context: context)
		sampleCard.playerName = "Sample Player"
		sampleCard.year = "2023"
		sampleCard.team = "Yankees"
		
		return QuickEditCardView(card: sampleCard)
			.environment(\.managedObjectContext, context)
	}
}
