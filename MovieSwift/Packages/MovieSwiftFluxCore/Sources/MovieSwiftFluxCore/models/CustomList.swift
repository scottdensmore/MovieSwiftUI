import Foundation
import SwiftUI

public struct CustomList: Codable, Identifiable, Sendable {
    public let id: Int
    public var name: String
    public var cover: Int?
    public var movies: Set<Int>

    public init(
        id: Int,
        name: String,
        cover: Int? = nil,
        movies: Set<Int>
    ) {
        self.id = id
        self.name = name
        self.cover = cover
        self.movies = movies
    }
}
