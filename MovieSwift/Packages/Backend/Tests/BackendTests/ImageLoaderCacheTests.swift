import XCTest
@testable import Backend

final class ImageLoaderCacheTests: XCTestCase {
    func testLoaderForReturnsSameInstanceForSamePathAndSize() {
        let cache = ImageLoaderCache()
        
        let first = cache.loaderFor(path: "/poster.jpg", size: .small)
        let second = cache.loaderFor(path: "/poster.jpg", size: .small)
        
        XCTAssertTrue(first === second)
    }
    
    func testLoaderForReturnsDifferentInstanceForDifferentSize() {
        let cache = ImageLoaderCache()
        
        let first = cache.loaderFor(path: "/poster.jpg", size: .small)
        let second = cache.loaderFor(path: "/poster.jpg", size: .medium)
        
        XCTAssertFalse(first === second)
    }
    
    func testLoaderForCachesMissingPathKey() {
        let cache = ImageLoaderCache()
        
        let first = cache.loaderFor(path: nil, size: .cast)
        let second = cache.loaderFor(path: nil, size: .cast)
        
        XCTAssertTrue(first === second)
    }
}
