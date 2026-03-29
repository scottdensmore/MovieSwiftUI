import Testing
import Foundation
@testable import Backend

@Suite("ImageService.Size")
struct ImageServiceSizeTests {
    @Test("path(poster:) builds correct URL for each size")
    func pathBuildExpectedURLs() {
        let poster = "/abc123.jpg"

        let small = ImageService.Size.small.path(poster: poster)
        #expect(small.absoluteString == "https://image.tmdb.org/t/p/w154/abc123.jpg")

        let medium = ImageService.Size.medium.path(poster: poster)
        #expect(medium.absoluteString == "https://image.tmdb.org/t/p/w500/abc123.jpg")

        let cast = ImageService.Size.cast.path(poster: poster)
        #expect(cast.absoluteString == "https://image.tmdb.org/t/p/w185/abc123.jpg")

        let original = ImageService.Size.original.path(poster: poster)
        #expect(original.absoluteString == "https://image.tmdb.org/t/p/original/abc123.jpg")
    }

    @Test("Size raw values are valid base URLs")
    func rawValuesAreValidURLs() {
        for size in [ImageService.Size.small, .medium, .cast, .original] {
            #expect(URL(string: size.rawValue) != nil)
        }
    }
}
