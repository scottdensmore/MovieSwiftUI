import Foundation

struct Video: Codable, Identifiable {
    let id: String
    let name: String
    let site: String
    let key: String
    let type: String
}
