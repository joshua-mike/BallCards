//
//  CardDetailView.swift
//  BallCards
//
//  Created by Josh May on 5/8/25.
//


// CardDetailView.swift
import SwiftUI
import CoreData

struct CardDetailView: View {
    @ObservedObject var card: Card
    @State private var isEditing = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Player name and basic info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.playerName ?? "Unknown Player")
                            .font(.largeTitle)
                            .bold()
                        
                        HStack {
                            Text(card.year ?? "Unknown Year")
                            if card.team != nil && !card.team!.isEmpty {
                                Text("•")
                                Text(card.team!)
                            }
                        }
                        .font(.title2)
                        
                        if card.cardNumber != nil && !card.cardNumber!.isEmpty {
                            Text("Card #\(card.cardNumber!)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Card images
                    HStack {
                        Spacer()
                        
                        VStack {
                            if let frontImageData = card.frontImage,
                               let frontImage = UIImage(data: frontImageData) {
                                Image(uiImage: frontImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 300)
                                    .cornerRadius(8)
                                
                                Text("Front")
                                    .font(.caption)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        VStack {
                            if let backImageData = card.backImage,
                               let backImage = UIImage(data: backImageData) {
                                Image(uiImage: backImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 300)
                                    .cornerRadius(8)
                                
                                Text("Back")
                                    .font(.caption)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Additional card details
                    VStack(alignment: .leading, spacing: 16) {
                        if card.series != nil && !card.series!.isEmpty {
                            DetailRow(label: "Series", value: card.series!)
                        }
                        
                        if card.manufacturer != nil && !card.manufacturer!.isEmpty {
                            DetailRow(label: "Manufacturer", value: card.manufacturer!)
                        }
                        
                        if card.position != nil && !card.position!.isEmpty {
                            DetailRow(label: "Position", value: card.position!)
                        }
                        
                        if card.condition != nil && !card.condition!.isEmpty {
                            DetailRow(label: "Condition", value: card.condition!)
                        }
                        
                        if let estimatedValue = card.estimated_value {
                            DetailRow(label: "Estimated Value", value: "$\(estimatedValue)")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes
                    if card.notes != nil && !card.notes!.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            
                            Text(card.notes!)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        isEditing = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationView {
                    CardEditView(card: card)
                }
            }
        }
    }
}

// Helper view for detail rows
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct CardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleCard = Card(context: context)
        sampleCard.playerName = "Babe Ruth"
        sampleCard.year = "1933"
        sampleCard.team = "Yankees"
        
        return CardDetailView(card: sampleCard)
    }
}
