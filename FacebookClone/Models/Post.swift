import Foundation

struct Post: Identifiable, Codable {
    var id: String
    var userID: String
    var text: String
    var imageURL: String?
    var timestamp: Date
}