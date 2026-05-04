import Foundation
import SwiftUI

struct Review: Codable, Identifiable {
    let id: String
    let author: String
    let content: String
}
