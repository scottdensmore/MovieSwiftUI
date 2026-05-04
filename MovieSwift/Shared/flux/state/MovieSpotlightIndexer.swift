//  Indexes user-saved movies (wishlist, seenlist, and every custom
//  list) into Apple's Core Spotlight so they appear in the system
//  search on iOS, iPadOS, and macOS. tvOS doesn't ship Core
//  Spotlight; the file exposes a no-op stub there so app entry
//  points can call `startObserving(store:)` unconditionally.
//
//  We deliberately don't index the full `state.moviesState.movies`
//  cache — that's a TMDB-shaped firehose of titles the user hasn't
//  asked to remember. Only items the user has explicitly added to a
//  list are surfaced so search results match the user's mental
//  model of "movies I saved".

import Foundation
#if canImport(CoreSpotlight) && !os(tvOS)
import CoreSpotlight
#endif
import SwiftUIFlux
import Combine

/// Pure-logic helpers — exposed regardless of platform so unit tests
/// can verify the indexable-set composition and identifier
/// round-tripping without depending on Core Spotlight.
enum MovieSpotlightIndexer {

    /// Domain identifier so the system groups these results
    /// together and the app can bulk-delete them on logout.
    static let domainIdentifier = "com.movieswift.movies"

    /// Identifier prefix. The numeric movie id is appended so
    /// `identifier(forMovieId:)` round-trips via
    /// `movieId(fromIdentifier:)` for the deep-link routing path.
    private static let identifierPrefix = "com.movieswift.movie."

    static func identifier(forMovieId id: Int) -> String {
        "\(identifierPrefix)\(id)"
    }

    /// Reverse of `identifier(forMovieId:)`. Returns nil for any
    /// other identifier shape so a future indexer change doesn't
    /// silently mis-parse existing entries.
    static func movieId(fromIdentifier identifier: String) -> Int? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let suffix = identifier.dropFirst(identifierPrefix.count)
        return Int(suffix)
    }

    /// Returns the union of wishlist + seenlist + custom-list movie
    /// ids. Pure so it can be unit-tested without spinning up a
    /// Core Spotlight index.
    static func indexableMovieIds(in state: AppState) -> Set<Int> {
        var ids = state.moviesState.wishlist
        ids.formUnion(state.moviesState.seenlist)
        for list in state.moviesState.customLists.values {
            ids.formUnion(list.movies)
        }
        return ids
    }
}

#if canImport(CoreSpotlight) && !os(tvOS)

/// Runtime indexer that subscribes to the SwiftUIFlux store and
/// keeps CSSearchableIndex in sync with the user's saved movies.
final class SpotlightStoreObserver {
    static let shared = SpotlightStoreObserver()

    private var lastIndexedIds: Set<Int> = []
    private var cancellable: AnyCancellable?
    private var lastSnapshot: AppState?
    private var isObserving = false

    private init() {}

    /// Subscribe to the store so wishlist / seenlist / custom-list
    /// changes update Spotlight as they happen. Idempotent — calling
    /// twice doesn't re-subscribe.
    func startObserving(store: Store<AppState>) {
        guard !isObserving else { return }
        isObserving = true

        // Index whatever's already in state at subscription time.
        update(state: store.state)

        // SwiftUIFlux's Store is an ObservableObject; objectWillChange
        // fires before mutations land, so we hop to the next runloop
        // tick to read the post-mutation state.
        cancellable = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak store] _ in
                DispatchQueue.main.async {
                    guard let self, let store else { return }
                    self.update(state: store.state)
                }
            }
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
        isObserving = false
    }

    /// Diffs the current indexable set against `lastIndexedIds`,
    /// adds new entries, and removes ones the user un-saved.
    /// Public for tests; production path runs through the
    /// store-subscription sink.
    func update(state: AppState) {
        let currentIds = MovieSpotlightIndexer.indexableMovieIds(in: state)
        let toAdd = currentIds.subtracting(lastIndexedIds)
        let toRemove = lastIndexedIds.subtracting(currentIds)
        // The cached movies dict is the source for the searchable
        // attributes (title, overview). If a movie is in the index
        // set but not yet in the cache (TMDB hasn't returned its
        // detail), skip it — it'll get re-tried on the next state
        // change.
        let itemsToIndex: [CSSearchableItem] = toAdd.compactMap { id in
            guard let movie = state.moviesState.movies[id] else { return nil }
            return SpotlightStoreObserver.makeSearchableItem(for: movie)
        }
        if !itemsToIndex.isEmpty {
            CSSearchableIndex.default().indexSearchableItems(itemsToIndex) { _ in }
        }
        if !toRemove.isEmpty {
            let identifiers = toRemove.map(MovieSpotlightIndexer.identifier(forMovieId:))
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { _ in }
        }

        // Track only ids actually surfaced to the index. If movie
        // detail wasn't in cache, leave the id out of
        // lastIndexedIds so the next update retries the add.
        let surfacedIds = Set(itemsToIndex.compactMap { item -> Int? in
            MovieSpotlightIndexer.movieId(fromIdentifier: item.uniqueIdentifier)
        })
        lastIndexedIds.formUnion(surfacedIds)
        lastIndexedIds.subtract(toRemove)
    }

    static func makeSearchableItem(for movie: Movie) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = movie.userTitle
        if !movie.overview.isEmpty {
            attributes.contentDescription = movie.overview
        }
        // TMDB's release_date is "yyyy-MM-dd". Surface as a content
        // creation date when present so the system can sort by it.
        if let release = movie.release_date,
           !release.isEmpty,
           let date = SpotlightStoreObserver.releaseDateFormatter.date(from: release) {
            attributes.contentCreationDate = date
        }
        return CSSearchableItem(
            uniqueIdentifier: MovieSpotlightIndexer.identifier(forMovieId: movie.id),
            domainIdentifier: MovieSpotlightIndexer.domainIdentifier,
            attributeSet: attributes
        )
    }

    private static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#else

/// tvOS doesn't ship Core Spotlight. Provide an API-compatible stub
/// so app entry points can call `SpotlightStoreObserver.shared
/// .startObserving(store:)` unconditionally.
final class SpotlightStoreObserver {
    static let shared = SpotlightStoreObserver()
    private init() {}
    func startObserving(store: Store<AppState>) {}
    func stopObserving() {}
    func update(state: AppState) {}
}

#endif
