import Foundation
import SwiftUI

public struct Review: Codable, Identifiable, Sendable {
    public let id: String
    public let author: String
    public let content: String

    public init(
        id: String,
        author: String,
        content: String
    ) {
        self.id = id
        self.author = author
        self.content = content
    }
}
