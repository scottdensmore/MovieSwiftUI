import Testing
@testable import Backend

// `@MainActor`: ImageLoaderCache / ImageLoader are main-actor-isolated.
@Suite @MainActor
struct ImageLoaderCacheTests {
    @Test func loaderForReturnsSameInstanceForSamePathAndSize() {
        let cache = ImageLoaderCache()

        let first = cache.loaderFor(path: "/poster.jpg", size: .small)
        let second = cache.loaderFor(path: "/poster.jpg", size: .small)

        #expect(first === second)
    }

    @Test func loaderForReturnsDifferentInstanceForDifferentSize() {
        let cache = ImageLoaderCache()

        let first = cache.loaderFor(path: "/poster.jpg", size: .small)
        let second = cache.loaderFor(path: "/poster.jpg", size: .medium)

        #expect(first !== second)
    }

    @Test func loaderForCachesMissingPathKey() {
        let cache = ImageLoaderCache()

        let first = cache.loaderFor(path: nil, size: .cast)
        let second = cache.loaderFor(path: nil, size: .cast)

        #expect(first === second)
    }

    @Test func clearRemovesCachedLoaders() {
        let cache = ImageLoaderCache()

        let first = cache.loaderFor(path: "/poster.jpg", size: .small)
        cache.clear()
        let second = cache.loaderFor(path: "/poster.jpg", size: .small)

        #expect(first !== second)
    }
}
