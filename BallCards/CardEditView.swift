// CardEditView.swift
import SwiftUI
import CoreData

struct CardEditView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@Environment(\.presentationMode) var presentationMode
	
	@ObservedObject var card: Card
	
	@State private var playerName: String
	@State private var year: String
	@State private var team: String
	@State private var cardNumber: String
	@State private var series: String
	@State private var manufacturer: String
	@State private var position: String
	@State private var condition: String
	@State private var notes: String
	@State private var estimatedValue: String
	
	@State private var showingDeleteAlert = false
	@State private var isShowingCamera = false
	@State private var isFrontCamera = true
	@State private var tempImage: UIImage?
	
	init(card: Card) {
		self.card = card
		
		// Initialize all state variables from card properties
		_playerName = State(initialValue: card.playerName ?? "")
		_year = State(initialValue: card.year ?? "")
		_team = State(initialValue: card.team ?? "")
		_cardNumber = State(initialValue: card.cardNumber ?? "")
		_series = State(initialValue: card.series ?? "")
		_manufacturer = State(initialValue: card.manufacturer ?? "")
		_position = State(initialValue: card.position ?? "")
		_condition = State(initialValue: card.condition ?? "")
		_notes = State(initialValue: card.notes ?? "")
		
		if let value = card.estimated_value {
			_estimatedValue = State(initialValue: "\(value)")
		} else {
			_estimatedValue = State(initialValue: "")
		}
	}
	
	var body: some View {
		Form {
			// Card images section
			Section(header: Text("Card Images")) {
				HStack {
					Spacer()
					
					// Front image with edit button
					VStack {
						if let frontImageData = card.frontImage,
						   let frontImage = UIImage(data: frontImageData) {
							Image(uiImage: frontImage)
								.resizable()
								.scaledToFit()
								.frame(height: 150)
								.cornerRadius(8)
						} else {
							RoundedRectangle(cornerRadius: 8)
								.fill(Color.gray.opacity(0.3))
								.frame(width: 100, height: 150)
								.overlay(
									Text("No Front Image")
										.font(.caption)
										.foregroundColor(.gray)
								)
						}
						
						Button("Edit Front") {
							isFrontCamera = true
							isShowingCamera = true
						}
						.font(.caption)
						.padding(.top, 4)
					}
					
					Spacer()
					
					// Back image with edit button
					VStack {
						if let backImageData = card.backImage,
						   let backImage = UIImage(data: backImageData) {
							Image(uiImage: backImage)
								.resizable()
								.scaledToFit()
								.frame(height: 150)
								.cornerRadius(8)
						} else {
							RoundedRectangle(cornerRadius: 8)
								.fill(Color.gray.opacity(0.3))
								.frame(width: 100, height: 150)
								.overlay(
									Text("No Back Image")
										.font(.caption)
										.foregroundColor(.gray)
								)
						}
						
						Button("Edit Back") {
							isFrontCamera = false
							isShowingCamera = true
						}
						.font(.caption)
						.padding(.top, 4)
					}
					
					Spacer()
				}
				.padding(.vertical, 10)
			}
			
			// Basic card information
			Section(header: Text("Card Information")) {
				TextField("Player Name", text: $playerName)
				TextField("Year", text: $year)
					.keyboardType(.numberPad)
				TextField("Team", text: $team)
				TextField("Card Number", text: $cardNumber)
			}
			
			// Additional information
			Section(header: Text("Additional Details")) {
				TextField("Series", text: $series)
				TextField("Manufacturer", text: $manufacturer)
				TextField("Position", text: $position)
				
				Picker("Condition", selection: $condition) {
					Text("Not Specified").tag("")
					Text("Mint").tag("Mint")
					Text("Near Mint").tag("Near Mint")
					Text("Excellent").tag("Excellent")
					Text("Very Good").tag("Very Good")
					Text("Good").tag("Good")
					Text("Fair").tag("Fair")
					Text("Poor").tag("Poor")
				}
				
				TextField("Estimated Value ($)", text: $estimatedValue)
					.keyboardType(.decimalPad)
			}
			
			// Notes section
			Section(header: Text("Notes")) {
				TextEditor(text: $notes)
					.frame(minHeight: 100)
			}
			
			// Delete button
			Section {
				Button(action: {
					showingDeleteAlert = true
				}) {
					HStack {
						Spacer()
						Text("Delete Card")
							.foregroundColor(.red)
						Spacer()
					}
				}
			}
		}
		.navigationTitle("Edit Card")
		.navigationBarItems(trailing: Button("Save") {
			saveCard()
			presentationMode.wrappedValue.dismiss()
		})
		.sheet(isPresented: $isShowingCamera) {
			CameraView(image: $tempImage, isFrontSide: $isFrontCamera) { capturedImage in
				if let image = capturedImage {
					if isFrontCamera {
						card.frontImage = image.jpegData(compressionQuality: 0.8)
					} else {
						card.backImage = image.jpegData(compressionQuality: 0.8)
					}
					
					if isFrontCamera {
						// Use OCR to extract data from front image
						CardRecognizer.shared.extractCardInfo(from: image) { cardInfo in
							if let cardInfo = cardInfo {
								// Only update empty fields with extracted data
								if playerName.isEmpty, let extractedName = cardInfo["playerName"] {
									playerName = extractedName
								}
								
								if year.isEmpty, let extractedYear = cardInfo["year"] {
									year = extractedYear
								}
								
								if team.isEmpty, let extractedTeam = cardInfo["team"] {
									team = extractedTeam
								}
								
								if cardNumber.isEmpty, let extractedNumber = cardInfo["cardNumber"] {
									cardNumber = extractedNumber
								}
							}
						}
					}
				}
			}
		}
		.alert(isPresented: $showingDeleteAlert) {
			Alert(
				title: Text("Delete Card"),
				message: Text("Are you sure you want to delete this card? This action cannot be undone."),
				primaryButton: .destructive(Text("Delete")) {
					deleteCard()
					presentationMode.wrappedValue.dismiss()
				},
				secondaryButton: .cancel()
			)
		}
	}
	
	private func saveCard() {
		// Update card with edited values
		card.playerName = playerName
		card.year = year
		card.team = team
		card.cardNumber = cardNumber
		card.series = series
		card.manufacturer = manufacturer
		card.position = position
		card.condition = condition
		card.notes = notes
		
		// Convert estimated value string to decimal
		if let value = Decimal(string: estimatedValue) {
			card.estimated_value = value as NSDecimalNumber
		} else {
			card.estimated_value = nil
		}
		
		// Mark as needing sync
		card.syncStatus = "pendingUpload"
		
		// Save context
		do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			print("Error saving card: \(nsError), \(nsError.userInfo)")
		}
	}
	
	private func deleteCard() {
		viewContext.delete(card)
		
		do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			print("Error deleting card: \(nsError), \(nsError.userInfo)")
		}
	}
}

struct CardEditView_Previews: PreviewProvider {
	static var previews: some View {
		let context = PersistenceController.preview.container.viewContext
		let sampleCard = Card(context: context)
		sampleCard.playerName = "Babe Ruth"
		sampleCard.year = "1933"
		sampleCard.team = "Yankees"
		
		return NavigationView {
			CardEditView(card: sampleCard)
		}
	}
}
