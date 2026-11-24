import Foundation

enum AppError: Error, LocalizedError, Equatable {
    case networkError(String)
    case apiError(Int, String)
    case quotaExceeded
    case noInternet
    case notFound
    case invalidResponse
    case unknown

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            return "API error \(code): \(message)"
        case .quotaExceeded:
            return "YouTube API quota has been exceeded."
        case .noInternet:
            return "No internet connection."
        case .notFound:
            return "The requested resource was not found."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unknown:
            return "An unknown error occurred."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your connection and try again."
        case .apiError:
            return "Please try again later or contact support."
        case .quotaExceeded:
            return "The daily API quota has been reached. Please try again tomorrow."
        case .noInternet:
            return "Connect to the internet and try again."
        case .notFound:
            return "The content may have been removed or made private."
        case .invalidResponse:
            return "Please try again. If the problem persists, update the app."
        case .unknown:
            return "Please try again later."
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let a), .networkError(let b)):
            return a == b
        case (.apiError(let c1, let m1), .apiError(let c2, let m2)):
            return c1 == c2 && m1 == m2
        case (.quotaExceeded, .quotaExceeded),
             (.noInternet, .noInternet),
             (.notFound, .notFound),
             (.invalidResponse, .invalidResponse),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
