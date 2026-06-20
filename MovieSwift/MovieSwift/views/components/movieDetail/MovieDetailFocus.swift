// `MovieDetailFocusModel` (below) is compiled everywhere except tvOS — the
// tvOS target doesn't build the detail-view focus rows — so its `Movie`/etc.
// inputs need these imports off tvOS. The focus *types* above stay
// dependency-free and unconditional.
#if !os(tvOS)
import Backend
import MovieSwiftFluxCore
#endif

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
    case video(String)
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
        case .video:                                return "row.videos"
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

#if !os(tvOS)
/// Pure computation of the macOS detail-view keyboard-focus targets from a
/// movie and its loaded relations.
///
/// Extracted from `MovieDetail` so the ~14 near-identical `*Targets` helpers
/// and the Tab-order assembly live in one testable place; the view keeps only
/// the `@FocusState` glue (`restoreDetailFocus`). All properties are pure
/// functions of the inputs, so the focus order is unit-tested directly without
/// standing up the view. Used only on macOS, but compiled off-tvOS so the
/// logic can be unit-tested on iOS too (the macOS unit-test host is flaky).
struct MovieDetailFocusModel {
    let movie: Movie?
    let characters: [People]?
    let credits: [People]?
    let similar: [Movie]?
    let recommended: [Movie]?
    let videos: [Video]?
    let reviewsCount: Int?
    /// Id of the primary credited person (director / top cast), pre-resolved by
    /// the caller — the selection logic stays with the view's `Props`.
    let topPersonId: Int?

    var genreTargets: [MovieDetailFocusTarget] {
        (movie?.genres ?? []).map { .genre($0.id) }
    }

    static let actionTargets: [MovieDetailFocusTarget] = [
        .wishlistButton, .seenlistButton, .customListButton,
    ]

    var reviewTarget: MovieDetailFocusTarget? {
        (reviewsCount ?? 0) > 0 ? .reviewLink : nil
    }

    var topPersonTarget: MovieDetailFocusTarget? {
        topPersonId.map { .topPerson($0) }
    }

    var readMoreTarget: MovieDetailFocusTarget? {
        guard let movie, !movie.overview.isEmpty else {
            return nil
        }
        return .readMoreButton
    }

    var keywordTargets: [MovieDetailFocusTarget] {
        (movie?.keywords?.keywords ?? []).map { .keyword($0.id) }
    }

    var castTargets: [MovieDetailFocusTarget] {
        guard let characters, !characters.isEmpty else {
            return []
        }
        return characters.map { .castPerson($0.id) } + [.castSeeAll]
    }

    var crewTargets: [MovieDetailFocusTarget] {
        guard let credits, !credits.isEmpty else {
            return []
        }
        return credits.map { .crewPerson($0.id) } + [.crewSeeAll]
    }

    var similarTargets: [MovieDetailFocusTarget] {
        guard let similar, !similar.isEmpty else {
            return []
        }
        return similar.map { .similarMovie($0.id) } + [.similarSeeAll]
    }

    var recommendedTargets: [MovieDetailFocusTarget] {
        guard let recommended, !recommended.isEmpty else {
            return []
        }
        return recommended.map { .recommendedMovie($0.id) } + [.recommendedSeeAll]
    }

    var posterTargets: [MovieDetailFocusTarget] {
        (movie?.images?.posters ?? []).map { .poster($0.filePath) }
    }

    var backdropTargets: [MovieDetailFocusTarget] {
        (movie?.images?.backdrops ?? []).map { .backdrop($0.filePath) }
    }

    var videoTargets: [MovieDetailFocusTarget] {
        MovieVideosState.presentations(from: videos ?? []).map { .video($0.id) }
    }

    /// Groups of focus targets, in Tab order. Each group is a horizontal row
    /// of related items (genres, action buttons, keywords, cast, crew etc).
    /// Tab / Shift+Tab moves between groups; Left/Right arrows move within.
    var focusGroups: [[MovieDetailFocusTarget]] {
        // Bind each computed group to a local so it's evaluated once — this is
        // called on every Tab/arrow key event, and `videoTargets` does a
        // non-trivial filter/map (`MovieVideosState.presentations`).
        var groups: [[MovieDetailFocusTarget]] = []
        let genres = genreTargets
        if !genres.isEmpty { groups.append(genres) }
        groups.append(Self.actionTargets)
        if let reviewTarget { groups.append([reviewTarget]) }
        if let topPersonTarget { groups.append([topPersonTarget]) }
        if let readMoreTarget { groups.append([readMoreTarget]) }
        let keywords = keywordTargets
        if !keywords.isEmpty { groups.append(keywords) }
        let cast = castTargets
        if !cast.isEmpty { groups.append(cast) }
        let crew = crewTargets
        if !crew.isEmpty { groups.append(crew) }
        let similar = similarTargets
        if !similar.isEmpty { groups.append(similar) }
        let recommended = recommendedTargets
        if !recommended.isEmpty { groups.append(recommended) }
        let videos = videoTargets
        if !videos.isEmpty { groups.append(videos) }
        let posters = posterTargets
        if !posters.isEmpty { groups.append(posters) }
        let backdrops = backdropTargets
        if !backdrops.isEmpty { groups.append(backdrops) }
        return groups
    }

    /// All targets flattened in Tab order — used to validate the currently
    /// focused item is still present after props change.
    var availableTopTargets: [MovieDetailFocusTarget] {
        focusGroups.flatMap { $0 }
    }

    /// Where focus should land when (re)entering the view: the first genre,
    /// else the first action button.
    var preferredFocusTarget: MovieDetailFocusTarget? {
        genreTargets.first ?? Self.actionTargets.first
    }
}
#endif
