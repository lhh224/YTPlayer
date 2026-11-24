// YouTubeAPIService.swift
// YTPlayer
//
// YouTube Data API v3 — phải hiển thị attribution theo YouTube API ToS
// See: https://developers.google.com/youtube/terms/required-minimum-functionality

import Foundation
import Combine

// MARK: - Internal Response Models (YouTube Data API v3 JSON format)

private struct YouTubeSearchResponse: Decodable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let pageInfo: YouTubePageInfo?
    let items: [YouTubeSearchItem]?
}

private struct YouTubePageInfo: Decodable {
    let totalResults: Int?
    let resultsPerPage: Int?
}

private struct YouTubeSearchItem: Decodable {
    let kind: String?
    let etag: String?
    let id: YouTubeItemID
    let snippet: YouTubeSnippet?
}

private struct YouTubeItemID: Decodable {
    let kind: String?
    let videoId: String?
}

private struct YouTubeSnippet: Decodable {
    let publishedAt: String?
    let channelId: String?
    let title: String
    let description: String?
    let thumbnails: YouTubeThumbnails
    let channelTitle: String
}

private struct YouTubeThumbnails: Decodable {
    let `default`: YouTubeThumbnailDetail?
    let medium: YouTubeThumbnailDetail?
    let high: YouTubeThumbnailDetail?
}

private struct YouTubeThumbnailDetail: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

// MARK: - Video Detail Response

private struct YouTubeVideoResponse: Decodable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let pageInfo: YouTubePageInfo?
    let items: [YouTubeVideoItem]?
}

private struct YouTubeVideoItem: Decodable {
    let kind: String?
    let etag: String?
    let id: String
    let snippet: YouTubeSnippet?
    let contentDetails: YouTubeContentDetails?
    let statistics: YouTubeStatistics?
}

private struct YouTubeContentDetails: Decodable {
    let duration: String?
}

private struct YouTubeStatistics: Decodable {
    let viewCount: String?
    let likeCount: String?
    let commentCount: String?
}

// MARK: - Google API Error Payload

private struct GoogleAPIErrorEnvelope: Decodable {
    let error: GoogleAPIErrorDetail
}

private struct GoogleAPIErrorDetail: Decodable {
    let code: Int
    let message: String
    let status: String?
    let errors: [GoogleAPIErrorReason]?
}

private struct GoogleAPIErrorReason: Decodable {
    let message: String?
    let domain: String?
    let reason: String?
}

// MARK: - Cache Entry

private struct CacheEntry {
    let data: SearchResult
    let timestamp: Date
}

// MARK: - Formatting Helpers

enum YouTubeFormatters {
    /// Converts ISO-8601 duration (e.g. "PT4M13S", "PT1H2M5S", "P0D") into human-readable "4:13", "1:02:05", or "LIVE".
    static func parseISO8601Duration(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        if iso == "P0D" || iso == "PT0S" {
            return "LIVE"
        }
        // Already formatted (e.g. "4:13")
        if iso.contains(":") {
            return iso
        }
        guard iso.hasPrefix("PT") else { return iso }

        var hours = 0
        var minutes = 0
        var seconds = 0
        var numberBuffer = ""

        for char in iso.dropFirst(2) {
            if char.isNumber {
                numberBuffer.append(char)
            } else {
                let val = Int(numberBuffer) ?? 0
                numberBuffer = ""
                switch char {
                case "H": hours = val
                case "M": minutes = val
                case "S": seconds = val
                default: break
                }
            }
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Decodes common HTML entities returned by YouTube search snippets.
    static func decodeHTMLEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// Extracts a 11-character YouTube video ID if the user pasted a YouTube link or ID.
    static func extractVideoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Direct 11-char ID check (only if it looks like an ID without spaces)
        let idAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if trimmed.count == 11,
           trimmed.rangeOfCharacter(from: idAllowed.inverted) == nil,
           trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil,
           trimmed.rangeOfCharacter(from: .decimalDigits) != nil {
            return trimmed
        }

        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return nil
        }

        if host.contains("youtu.be") {
            let candidate = url.pathComponents.dropFirst().first ?? ""
            return candidate.count == 11 ? candidate : nil
        }

        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
               v.count == 11 {
                return v
            }
            let parts = url.pathComponents
            if let idx = parts.firstIndex(where: { $0 == "shorts" || $0 == "embed" || $0 == "live" }),
               parts.indices.contains(idx + 1) {
                let candidate = parts[idx + 1]
                return candidate.count == 11 ? candidate : nil
            }
        }
        return nil
    }
}

// MARK: - YouTubeAPIService

final class YouTubeAPIService: ObservableObject {

    static let shared = YouTubeAPIService()
    static let customAPIKeyDefaultsKey = "customYouTubeAPIKey"

    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes
    private var cache: [String: CacheEntry] = [:]
    private let decoder = JSONDecoder()

    /// Resolves the active API key: UserDefaults override -> Info.plist -> Config/APIKeys.plist
    var currentAPIKey: String {
        if let custom = UserDefaults.standard.string(forKey: Self.customAPIKeyDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }

        if let key = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "YOUR_API_KEY_HERE" {
                return trimmed
            }
        }

        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["YouTubeAPIKey"] as? String {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "YOUR_API_KEY_HERE" {
                return trimmed
            }
        }

        return ""
    }

    var hasConfiguredAPIKey: Bool {
        !currentAPIKey.isEmpty
    }

    private init() {}

    /// Updates or clears the user-configured API key at runtime and clears cached responses.
    func updateAPIKey(_ newKey: String) {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.customAPIKeyDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.customAPIKeyDefaultsKey)
        }
        clearCache()
        objectWillChange.send()
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Public API

    /// Validates an API key by performing a lightweight 1-item videos.list request (costs 1 quota unit).
    func validateAPIKey(_ candidateKey: String? = nil) async throws -> String {
        let keyToTest = (candidateKey ?? currentAPIKey).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyToTest.isEmpty else {
            throw AppError.apiError(400, "Chưa nhập YouTube Data API v3 Key.")
        }

        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "id", value: "dQw4w9WgXcQ"),
            URLQueryItem(name: "key", value: keyToTest)
        ]
        let url = try buildURL(path: "/videos", queryItems: queryItems)
        let response: YouTubeVideoResponse = try await fetchDecoded(url: url)
        guard let first = response.items?.first else {
            throw AppError.invalidResponse
        }
        return first.snippet?.title ?? "OK"
    }

    /// Search videos by query string (or direct YouTube URL/ID) with optional pagination token.
    func searchVideos(query: String, pageToken: String? = nil) async throws -> SearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return SearchResult(items: [], nextPageToken: nil, totalResults: 0)
        }

        // If user pasted a direct YouTube URL or 11-char Video ID, fetch exact video or create playable item
        if pageToken == nil, let directId = YouTubeFormatters.extractVideoID(from: trimmedQuery) {
            if hasConfiguredAPIKey, let detail = try? await fetchVideoDetail(videoId: directId) {
                return SearchResult(items: [detail], nextPageToken: nil, totalResults: 1)
            } else {
                let directItem = VideoItem(
                    id: directId,
                    title: "Video YouTube (\(directId))",
                    channelName: "YouTube Direct Link",
                    channelId: "",
                    thumbnailURL: "https://i.ytimg.com/vi/\(directId)/hqdefault.jpg",
                    duration: "Video",
                    viewCount: "",
                    publishedAt: "",
                    description: "Phát trực tiếp từ đường dẫn/ID YouTube: \(directId)"
                )
                return SearchResult(items: [directItem], nextPageToken: nil, totalResults: 1)
            }
        }

        let key = currentAPIKey
        guard !key.isEmpty else {
            throw AppError.apiError(401, "Chưa cấu hình YouTube Data API v3 Key trong Cài đặt hoặc APIKeys.plist.")
        }

        let cacheKey = pageToken.map { "\(trimmedQuery.lowercased())_search_\($0)" } ?? "\(trimmedQuery.lowercased())_search"
        if let cached = cachedResult(for: cacheKey) {
            return cached
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "key", value: key)
        ]
        if let token = pageToken {
            items.append(URLQueryItem(name: "pageToken", value: token))
        }

        let url = try buildURL(path: "/search", queryItems: items)
        let response: YouTubeSearchResponse = try await fetchDecoded(url: url)
        var baseResult = mapSearchResponse(response)

        // Batch-enrich duration & viewCount via /videos (costs only 1 quota unit total!)
        if !baseResult.items.isEmpty {
            let ids = baseResult.items.map { $0.id }.joined(separator: ",")
            if let detailsMap = try? await fetchBatchVideoStats(idsCSV: ids, apiKey: key) {
                let enriched = baseResult.items.map { item -> VideoItem in
                    guard let meta = detailsMap[item.id] else { return item }
                    return VideoItem(
                        id: item.id,
                        title: item.title,
                        channelName: item.channelName,
                        channelId: item.channelId,
                        thumbnailURL: item.thumbnailURL,
                        duration: meta.duration,
                        viewCount: meta.viewCount,
                        publishedAt: item.publishedAt,
                        description: meta.description.isEmpty ? item.description : meta.description
                    )
                }
                baseResult = SearchResult(
                    items: enriched,
                    nextPageToken: baseResult.nextPageToken,
                    totalResults: baseResult.totalResults
                )
            }
        }

        storeInCache(baseResult, for: cacheKey)
        return baseResult
    }

    /// Fetch trending videos for a given region (default: Vietnam).
    func fetchTrending(regionCode: String = "VN", pageToken: String? = nil) async throws -> SearchResult {
        let key = currentAPIKey
        guard !key.isEmpty else {
            throw AppError.apiError(401, "Chưa cấu hình YouTube Data API v3 Key.")
        }

        let cacheKey = pageToken.map { "trending_\(regionCode)_\($0)" } ?? "trending_\(regionCode)"
        if let cached = cachedResult(for: cacheKey) {
            return cached
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "key", value: key)
        ]
        if let token = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: token))
        }

        let url = try buildURL(path: "/videos", queryItems: queryItems)
        let response: YouTubeVideoResponse = try await fetchDecoded(url: url)
        let result = mapVideoResponse(response)
        storeInCache(result, for: cacheKey)
        return result
    }

    /// Fetch detail for a single video by its ID.
    func fetchVideoDetail(videoId: String) async throws -> VideoItem {
        let key = currentAPIKey
        guard !key.isEmpty else {
            throw AppError.apiError(401, "Chưa cấu hình YouTube Data API v3 Key.")
        }

        let cacheKey = "detail_\(videoId)"
        if let cached = cachedResult(for: cacheKey), let first = cached.items.first {
            return first
        }

        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "id", value: videoId),
            URLQueryItem(name: "key", value: key)
        ]

        let url = try buildURL(path: "/videos", queryItems: queryItems)
        let response: YouTubeVideoResponse = try await fetchDecoded(url: url)

        guard let item = response.items?.first else {
            throw AppError.notFound
        }
        let mapped = mapVideoItem(item)
        storeInCache(SearchResult(items: [mapped], nextPageToken: nil, totalResults: 1), for: cacheKey)
        return mapped
    }

    // MARK: - Private Helpers

    private func fetchBatchVideoStats(idsCSV: String, apiKey: String) async throws -> [String: (duration: String, viewCount: String, description: String)] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "id", value: idsCSV),
            URLQueryItem(name: "key", value: apiKey)
        ]
        let url = try buildURL(path: "/videos", queryItems: queryItems)
        let response: YouTubeVideoResponse = try await fetchDecoded(url: url)
        var map: [String: (String, String, String)] = [:]
        for item in response.items ?? [] {
            let duration = YouTubeFormatters.parseISO8601Duration(item.contentDetails?.duration ?? "")
            let views = item.statistics?.viewCount ?? ""
            let desc = item.snippet?.description ?? ""
            map[item.id] = (duration, views, desc)
        }
        return map
    }

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw AppError.networkError("URL không hợp lệ cho đường dẫn: \(path)")
        }
        return url
    }

    private func fetchDecoded<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw AppError.noInternet
        } catch {
            throw AppError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw parseGoogleAPIError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.networkError("Lỗi giải mã JSON: \(error.localizedDescription)")
        }
    }

    private func parseGoogleAPIError(statusCode: Int, data: Data) -> AppError {
        if let envelope = try? decoder.decode(GoogleAPIErrorEnvelope.self, from: data) {
            let reason = envelope.error.errors?.first?.reason ?? envelope.error.status ?? ""
            let message = envelope.error.message

            if reason == "quotaExceeded" || reason == "dailyLimitExceeded" || statusCode == 429 {
                return .quotaExceeded
            }
            if statusCode == 403 && (reason == "forbidden" || reason == "accessNotConfigured" || envelope.error.status == "PERMISSION_DENIED") {
                return .apiError(403, "YouTube Data API v3 chưa được bật cho API Key này trên Google Cloud Console (PERMISSION_DENIED). Hãy vào APIs & Services → Library → bật 'YouTube Data API v3' hoặc nhập API Key khác trong Cài đặt.")
            }
            if statusCode == 400 && (reason == "keyInvalid" || message.lowercased().contains("api key not valid")) {
                return .apiError(400, "API Key không hợp lệ. Vui lòng kiểm tra lại khóa trong Cài đặt.")
            }
            return .apiError(statusCode, message)
        }

        switch statusCode {
        case 429:
            return .quotaExceeded
        case 404:
            return .notFound
        default:
            return .apiError(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }

    // MARK: - Mapping

    private func mapSearchResponse(_ response: YouTubeSearchResponse) -> SearchResult {
        let items = (response.items ?? []).compactMap { item -> VideoItem? in
            guard let videoId = item.id.videoId, let snippet = item.snippet else { return nil }
            let thumb = snippet.thumbnails.high?.url
                ?? snippet.thumbnails.medium?.url
                ?? snippet.thumbnails.default?.url
                ?? "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
            return VideoItem(
                id: videoId,
                title: YouTubeFormatters.decodeHTMLEntities(snippet.title),
                channelName: YouTubeFormatters.decodeHTMLEntities(snippet.channelTitle),
                channelId: snippet.channelId ?? "",
                thumbnailURL: thumb,
                duration: "",
                viewCount: "",
                publishedAt: formatDateString(snippet.publishedAt ?? ""),
                description: snippet.description ?? ""
            )
        }
        return SearchResult(
            items: items,
            nextPageToken: response.nextPageToken,
            totalResults: response.pageInfo?.totalResults ?? items.count
        )
    }

    private func mapVideoResponse(_ response: YouTubeVideoResponse) -> SearchResult {
        let items = (response.items ?? []).map { mapVideoItem($0) }
        return SearchResult(
            items: items,
            nextPageToken: response.nextPageToken,
            totalResults: response.pageInfo?.totalResults ?? items.count
        )
    }

    private func mapVideoItem(_ item: YouTubeVideoItem) -> VideoItem {
        let thumbnailURL = item.snippet?.thumbnails.high?.url
            ?? item.snippet?.thumbnails.medium?.url
            ?? item.snippet?.thumbnails.default?.url
            ?? "https://i.ytimg.com/vi/\(item.id)/hqdefault.jpg"
        return VideoItem(
            id: item.id,
            title: YouTubeFormatters.decodeHTMLEntities(item.snippet?.title ?? ""),
            channelName: YouTubeFormatters.decodeHTMLEntities(item.snippet?.channelTitle ?? ""),
            channelId: item.snippet?.channelId ?? "",
            thumbnailURL: thumbnailURL,
            duration: YouTubeFormatters.parseISO8601Duration(item.contentDetails?.duration ?? ""),
            viewCount: item.statistics?.viewCount ?? "",
            publishedAt: formatDateString(item.snippet?.publishedAt ?? ""),
            description: item.snippet?.description ?? ""
        )
    }

    private func formatDateString(_ raw: String) -> String {
        guard raw.count >= 10 else { return raw }
        return String(raw.prefix(10))
    }

    // MARK: - Cache

    private func cachedResult(for key: String) -> SearchResult? {
        guard let entry = cache[key], !isCacheExpired(entry.timestamp) else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    private func storeInCache(_ result: SearchResult, for key: String) {
        cache[key] = CacheEntry(data: result, timestamp: Date())
    }

    private func isCacheExpired(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) > cacheTTL
    }
}
