import Testing
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `.serialized`: the tests mutate the `IntentActionStore.shared` singleton,
// so they must not run in parallel and clobber each other.
@MainActor
@Suite(.serialized) struct IntentActionStoreTests {
    @Test func requestOverwritesAnyExistingPendingAction() {
        let store = IntentActionStore.shared
        store.request(.markAsSeen(movie: 1))

        store.request(.addToWishlist(movie: 42))

        #expect(store.pendingAction == .addToWishlist(movie: 42))
        store.consume()
    }

    @Test func consumeReturnsAndClearsTheWishlistAction() {
        let store = IntentActionStore.shared
        store.request(.addToWishlist(movie: 7))

        #expect(store.consume() == .addToWishlist(movie: 7))
        #expect(store.pendingAction == nil)
        // A second consume with nothing pending returns nil.
        #expect(store.consume() == nil)
    }

    @Test func consumeReturnsAndClearsTheSeenAction() {
        let store = IntentActionStore.shared
        store.request(.markAsSeen(movie: 9))

        #expect(store.consume() == .markAsSeen(movie: 9))
        #expect(store.pendingAction == nil)
    }
}
