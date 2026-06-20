import Foundation
import SwiftUI

public struct ImageData: Codable, Identifiable, Sendable {

    public init(
        aspectRatio: Float,
        filePath: String,
        height: Int,
        width: Int
    ) {
        self.aspectRatio = aspectRatio
        self.filePath = filePath
        self.height = height
        self.width = width
    }

    public let aspectRatio: Float
    public let filePath: String
    public let height: Int
    public let width: Int

    // Swift properties are camelCase; the TMDB JSON keys (and the keys
    // persisted in user backups) are snake_case. `CodingKeys` bridges the
    // two so the decoded/encoded wire format is unchanged.
    public enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspect_ratio"
        case filePath = "file_path"
        case height
        case width
    }

    public var id: String {
        filePath
    }
}
