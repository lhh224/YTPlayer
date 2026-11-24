import Foundation

struct SearchResult: Codable {
    let items: [VideoItem]
    let nextPageToken: String?
    let totalResults: Int
}
