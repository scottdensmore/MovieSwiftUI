import Foundation

public struct MovieUserMeta: Codable {
    public var addedToList: Date?

    public init(
        addedToList: Date? = nil
    ) {
        self.addedToList = addedToList
    }
}
