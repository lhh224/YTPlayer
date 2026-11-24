import Foundation

struct Channel: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnailURL: String
    let subscriberCount: String
}
