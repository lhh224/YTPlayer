import Foundation

final class NetworkClient {

    // MARK: - Shared Instance

    static let shared = NetworkClient()

    // MARK: - Private Properties

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Fetch via Endpoint

    func fetch<T: Decodable>(_ endpoint: any Endpoint) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        return try await fetch(url: url)
    }

    // MARK: - Fetch via URL

    func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
