// `nonisolated`: a pure focus-identity value type used as a `@FocusState`
// value, whose Hashable conformance is consumed by nonisolated SwiftUI
// internals — it must not inherit the app target's default main-actor
// isolation.
nonisolated enum MovieDetailFocusTarget: Hashable {
    case genre(Int)
    case wishlistButton
    case seenlistButton
    case customListButton
    case reviewLink
    case topPerson(Int)
    case readMoreButton
    case keyword(Int)
    case castPerson(Int)
    case castSeeAll
    case crewPerson(Int)
    case crewSeeAll
    case similarMovie(Int)
    case similarSeeAll
    case recommendedMovie(Int)
    case recommendedSeeAll
    case poster(String)
    case backdrop(String)
}

/// Maps a focus target to the scroll-anchor id of the row it lives in.
/// Used by the outer ScrollViewReader to scroll the focused row into
/// view when Tab / Shift+Tab jumps to an off-screen section.
enum MovieDetailFocusRow {
    static func scrollId(for target: MovieDetailFocusTarget) -> String {
        switch target {
        case .genre:                                return "row.cover"
        case .wishlistButton,
             .seenlistButton,
             .customListButton:                     return "row.buttons"
        case .reviewLink:                           return "row.review"
        case .topPerson:                            return "row.director"
        case .readMoreButton:                       return "row.overview"
        case .keyword:                              return "row.keywords"
        case .castPerson, .castSeeAll:              return "row.cast"
        case .crewPerson, .crewSeeAll:              return "row.crew"
        case .similarMovie, .similarSeeAll:         return "row.similar"
        case .recommendedMovie, .recommendedSeeAll: return "row.recommended"
        case .poster:                               return "row.posters"
        case .backdrop:                             return "row.backdrops"
        }
    }
}

/// Pure navigation decisions for the detail view's Tab / arrow focus.
/// Groups are passed in so tests can exercise the logic without a view.
enum MovieDetailFocusNavigation {
    /// Tab / Shift+Tab — jump to the first item of the next/previous group.
    /// When current is nil, returns the first (or last) group's first item.
    /// Returns nil if at the edge.
    static func nextGroupStart(from current: MovieDetailFocusTarget?,
                               in groups: [[MovieDetailFocusTarget]],
                               forward: Bool) -> MovieDetailFocusTarget? {
        guard !groups.isEmpty else { return nil }
        guard let current else {
            return forward ? groups.first?.first : groups.last?.first
        }
        guard let currentGroup = groups.firstIndex(where: { $0.contains(current) }) else {
            return forward ? groups.first?.first : groups.last?.first
        }
        let nextGroup = currentGroup + (forward ? 1 : -1)
        guard groups.indices.contains(nextGroup) else { return nil }
        return groups[nextGroup].first
    }

    /// Left / Right arrow — move within the current group only. Returns nil
    /// at the edge so the caller can leave focus alone.
    static func adjacentInGroup(from current: MovieDetailFocusTarget,
                                in groups: [[MovieDetailFocusTarget]],
                                forward: Bool) -> MovieDetailFocusTarget? {
        guard let group = groups.first(where: { $0.contains(current) }),
              let idx = group.firstIndex(of: current) else {
            return nil
        }
        let nextIdx = idx + (forward ? 1 : -1)
        guard group.indices.contains(nextIdx) else { return nil }
        return group[nextIdx]
    }
}
