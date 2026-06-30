import Foundation

/// Records the most recent Discover card removal so the view can offer a true
/// undo: which movie left the deck, and where it went. Stored on
/// `MoviesState.discoverLastSwipe`.
public struct DiscoverSwipe: Codable, Equatable, Sendable {
    /// Where a swiped/removed card went. `skip` is the "Skip movie" button —
    /// removed from the deck without being added to any list.
    public enum Destination: String, Codable, Equatable, Sendable {
        case wishlist
        case seenlist
        case skip
    }

    public let movie: Int
    public let destination: Destination

    public init(movie: Int, destination: Destination) {
        self.movie = movie
        self.destination = destination
    }

    /// What undoing this swipe must remove. `skip` added the movie to no list,
    /// so undoing it only re-decks the card (`.none`).
    public enum UndoRemoval: Equatable, Sendable {
        case wishlist(Int)
        case seenlist(Int)
        case none
    }

    public var undoRemoval: UndoRemoval {
        switch destination {
        case .wishlist: return .wishlist(movie)
        case .seenlist: return .seenlist(movie)
        case .skip: return .none
        }
    }
}
