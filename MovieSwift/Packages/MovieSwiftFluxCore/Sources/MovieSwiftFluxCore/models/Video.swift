import Foundation

public struct Video: Codable, Identifiable {
    public let id: String
    public let name: String
    public let site: String
    public let key: String
    public let type: String

    public init(
        id: String,
        name: String,
        site: String,
        key: String,
        type: String
    ) {
        self.id = id
        self.name = name
        self.site = site
        self.key = key
        self.type = type
    }
}
