import Foundation
import SwiftUI

public struct People: Codable, Identifiable {
    public let id: Int
    public let name: String
    public var character: String?
    public var department: String?
    public let profile_path: String?
        
    public let known_for_department: String?
    public var known_for: [KnownFor]?
    public let also_known_as: [String]?
    
    public let birthDay: String?
    public let deathDay: String?
    public let place_of_birth: String?
    
    public let biography: String?
    public let popularity: Double?
    
    public var images: [ImageData]?

    public init(
        id: Int,
        name: String,
        character: String? = nil,
        department: String? = nil,
        profile_path: String? = nil,
        known_for_department: String? = nil,
        known_for: [KnownFor]? = nil,
        also_known_as: [String]? = nil,
        birthDay: String? = nil,
        deathDay: String? = nil,
        place_of_birth: String? = nil,
        biography: String? = nil,
        popularity: Double? = nil,
        images: [ImageData]? = nil
    ) {
        self.id = id
        self.name = name
        self.character = character
        self.department = department
        self.profile_path = profile_path
        self.known_for_department = known_for_department
        self.known_for = known_for
        self.also_known_as = also_known_as
        self.birthDay = birthDay
        self.deathDay = deathDay
        self.place_of_birth = place_of_birth
        self.biography = biography
        self.popularity = popularity
        self.images = images
    }
    
    public struct KnownFor: Codable, Identifiable {
        public let id: Int
        public let original_title: String?
        public let poster_path: String?

        public init(
            id: Int,
            original_title: String? = nil,
            poster_path: String? = nil
        ) {
            self.id = id
            self.original_title = original_title
            self.poster_path = poster_path
        }
    }
}

public extension People {
    public var knownForText: String? {
        guard let knownFor = known_for else {
            return nil
        }
        let names = knownFor.filter{ $0.original_title != nil}.map{ $0.original_title! }
        return names.joined(separator: ", ")
    }
}
