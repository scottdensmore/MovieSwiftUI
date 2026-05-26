import Foundation

public struct PaginatedResponse<T: Codable>: Codable {
    public let page: Int?
    public let total_results: Int?
    public let total_pages: Int?
    public let results: [T]

    public init(
        page: Int? = nil,
        total_results: Int? = nil,
        total_pages: Int? = nil,
        results: [T]
    ) {
        self.page = page
        self.total_results = total_results
        self.total_pages = total_pages
        self.results = results
    }
}

// Conditionally Sendable: a paginated payload is just immutable value
// fields plus `[T]`, so it's safe to share whenever its element type is.
extension PaginatedResponse: Sendable where T: Sendable {}
