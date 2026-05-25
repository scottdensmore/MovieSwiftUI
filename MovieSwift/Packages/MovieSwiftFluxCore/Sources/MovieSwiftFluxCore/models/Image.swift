import Foundation
import SwiftUI

public struct ImageData: Codable, Identifiable, Sendable {

    public init(
        aspect_ratio: Float,
        file_path: String,
        height: Int,
        width: Int
    ) {
        self.aspect_ratio = aspect_ratio
        self.file_path = file_path
        self.height = height
        self.width = width
    }
    public var id: String {
        file_path
    }
    public let aspect_ratio: Float
    public let file_path: String
    public let height: Int
    public let width: Int
}
