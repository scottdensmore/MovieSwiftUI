import Foundation
import SwiftUI

struct CustomList: Codable, Identifiable {
    let id: Int
    var name: String
    var cover: Int?
    var movies: Set<Int>
}
