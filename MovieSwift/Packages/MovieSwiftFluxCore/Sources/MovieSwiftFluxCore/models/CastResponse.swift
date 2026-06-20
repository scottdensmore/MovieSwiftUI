import Foundation

public struct CastResponse: Codable, Sendable {
    public let id: Int
    public let cast: [People]
    public let crew: [People]

    public init(
        id: Int,
        cast: [People],
        crew: [People]
    ) {
        self.id = id
        self.cast = cast
        self.crew = crew
    }
}

public let sampleCasts = [People(id: 0,
                          name: "Cast 1",
                          character: "Character 1",
                          department: nil,
                          profilePath: "/2daC5DeXqwkFND0xxutbnSVKN6c.jpg",
                          knownForDepartment: "Acting",
                          // KnownFor labels are camelCase; `sampleMovie`'s
                          // fields stay snake_case until the Movie model is
                          // migrated in its own PR.
                          knownFor: [People.KnownFor(id: sampleMovie.id,
                                                      originalTitle: sampleMovie.original_title,
                                                      posterPath: sampleMovie.poster_path), ],
                          alsoKnownAs: nil, birthDay: nil,
                          deathDay: nil, placeOfBirth: nil,
                          biography: nil, popularity: nil, images: nil),
                   People(id: 1, name: "Cast 2", character: nil, department: "Director 1", profilePath: "/2daC5DeXqwkFND0xxutbnSVKN6c.jpg",
                          knownForDepartment: "Acting", knownFor: nil,
                          alsoKnownAs: nil, birthDay: nil, deathDay: nil, placeOfBirth: nil,
                          biography: nil, popularity: nil, images: nil), ]
