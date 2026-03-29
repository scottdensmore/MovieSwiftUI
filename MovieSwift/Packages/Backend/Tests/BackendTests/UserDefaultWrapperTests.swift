import Testing
import Foundation
@testable import Backend

@Suite("UserDefault property wrapper")
struct UserDefaultWrapperTests {
    @Test("get returns default when key is missing")
    func getReturnsDefault() {
        let key = "test_missing_key_\(UUID().uuidString)"
        var wrapper = UserDefault<String>(key, defaultValue: "fallback")
        #expect(wrapper.wrappedValue == "fallback")
    }

    @Test("set persists value and get retrieves it")
    func setAndGet() {
        let key = "test_roundtrip_\(UUID().uuidString)"
        var wrapper = UserDefault<Int>(key, defaultValue: 0)
        wrapper.wrappedValue = 42
        #expect(wrapper.wrappedValue == 42)
        // cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("AppUserDefaults.region returns a non-empty string")
    func regionHasValue() {
        #expect(!AppUserDefaults.region.isEmpty)
    }
}
