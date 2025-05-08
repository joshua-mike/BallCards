import FirebaseFirestoreSwift

struct CardData: Codable, Identifiable {
    @DocumentID var documentID: String?
    var id: String
    var dateAdded: Date
    var playerName: String
    var year: String
    var team: String
    var cardNumber: String?
    var series: String?
    var condition: String?
    var notes: String?
    var frontImageURL: String?
    var backImageURL: String?
}