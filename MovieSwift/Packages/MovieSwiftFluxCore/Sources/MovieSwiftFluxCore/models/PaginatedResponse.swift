import Foundation

public struct PaginatedResponse<T: Codable>: Codable {
    public let page: Int?
    public let totalResults: Int?
    public let totalPages: Int?
    public let results: [T]

    // Swift properties are camelCase; the TMDB JSON keys are snake_case.
    // `CodingKeys` bridges the two so the decoded/encoded wire format is
    // unchanged while call sites read idiomatically.
    public enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case totalPages = "total_pages"
        case results
    }

    public init(
        page: Int? = nil,
        totalResults: Int? = nil,
        totalPages: Int? = nil,
        results: [T]
    ) {
        self.page = page
        self.totalResults = totalResults
        self.totalPages = totalPages
        self.results = results
    }
}

// Conditionally Sendable: a paginated payload is just immutable value
// fields plus `[T]`, so it's safe to share whenever its element type is.
extension PaginatedResponse: Sendable where T: Sendable {}
