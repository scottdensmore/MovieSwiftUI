import Foundation
import SwiftUI

public struct People: Codable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public var character: String?
    public var department: String?
    public let profilePath: String?

    public let knownForDepartment: String?
    public var knownFor: [KnownFor]?
    public let alsoKnownAs: [String]?

    public let birthDay: String?
    public let deathDay: String?
    public let placeOfBirth: String?

    public let biography: String?
    public let popularity: Double?

    public var images: [ImageData]?

    // Swift properties are camelCase; the TMDB JSON keys (and the keys
    // persisted in user backups) are snake_case. `CodingKeys` bridges the
    // two so the decoded/encoded wire format is unchanged. `birthDay` and
    // `deathDay` were already camelCase, so they keep those exact wire keys
    // (the fixtures and persisted backups use `birthDay`/`deathDay`).
    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case department
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        case knownFor = "known_for"
        case alsoKnownAs = "also_known_as"
        case birthDay
        case deathDay
        case placeOfBirth = "place_of_birth"
        case biography
        case popularity
        case images
    }

    public init(
        id: Int,
        name: String,
        character: String? = nil,
        department: String? = nil,
        profilePath: String? = nil,
        knownForDepartment: String? = nil,
        knownFor: [KnownFor]? = nil,
        alsoKnownAs: [String]? = nil,
        birthDay: String? = nil,
        deathDay: String? = nil,
        placeOfBirth: String? = nil,
        biography: String? = nil,
        popularity: Double? = nil,
        images: [ImageData]? = nil
    ) {
        self.id = id
        self.name = name
        self.character = character
        self.department = department
        self.profilePath = profilePath
        self.knownForDepartment = knownForDepartment
        self.knownFor = knownFor
        self.alsoKnownAs = alsoKnownAs
        self.birthDay = birthDay
        self.deathDay = deathDay
        self.placeOfBirth = placeOfBirth
        self.biography = biography
        self.popularity = popularity
        self.images = images
    }

    public struct KnownFor: Codable, Identifiable, Sendable {
        public let id: Int
        public let originalTitle: String?
        public let posterPath: String?

        // `CodingKeys` must nest in its conforming type, which is itself
        // nested one level inside `People` — unavoidably two levels deep.
        // swiftlint:disable:next nesting
        public enum CodingKeys: String, CodingKey {
            case id
            case originalTitle = "original_title"
            case posterPath = "poster_path"
        }

        public init(
            id: Int,
            originalTitle: String? = nil,
            posterPath: String? = nil
        ) {
            self.id = id
            self.originalTitle = originalTitle
            self.posterPath = posterPath
        }
    }
}

public extension People {
    var knownForText: String? {
        guard let knownFor else {
            return nil
        }
        let names = knownFor.compactMap { $0.originalTitle }
        return names.joined(separator: ", ")
    }
}
