import Foundation

// MARK: - Endpoint Protocol

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
    var method: String { get }
}

extension Endpoint {
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }
}

// MARK: - YouTubeEndpoint

enum YouTubeEndpoint: Endpoint {
    case search(query: String, pageToken: String?, apiKey: String)
    case trending(regionCode: String, apiKey: String)
    case videoDetail(videoId: String, apiKey: String)

    // MARK: Endpoint Properties

    var baseURL: String {
        return "https://www.googleapis.com"
    }

    var path: String {
        switch self {
        case .search:
            return "/youtube/v3/search"
        case .trending:
            return "/youtube/v3/videos"
        case .videoDetail:
            return "/youtube/v3/videos"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .search(let query, let pageToken, let apiKey):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "type", value: "video"),
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "maxResults", value: "25"),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let token = pageToken {
                items.append(URLQueryItem(name: "pageToken", value: token))
            }
            return items

        case .trending(let regionCode, let apiKey):
            return [
                URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
                URLQueryItem(name: "chart", value: "mostPopular"),
                URLQueryItem(name: "regionCode", value: regionCode),
                URLQueryItem(name: "maxResults", value: "25"),
                URLQueryItem(name: "key", value: apiKey)
            ]

        case .videoDetail(let videoId, let apiKey):
            return [
                URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
                URLQueryItem(name: "id", value: videoId),
                URLQueryItem(name: "key", value: apiKey)
            ]
        }
    }

    var method: String {
        return "GET"
    }
}
