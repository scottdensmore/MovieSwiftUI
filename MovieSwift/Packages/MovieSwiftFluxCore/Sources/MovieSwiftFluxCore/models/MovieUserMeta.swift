import Foundation

public struct MovieUserMeta: Codable, Sendable {
    public var addedToList: Date?

    public init(
        addedToList: Date? = nil
    ) {
        self.addedToList = addedToList
    }
}
