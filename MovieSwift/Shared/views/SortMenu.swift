import SwiftUI
import MovieSwiftFluxCore

// `@MainActor`: this builds SwiftUI `Button`s whose actions capture the
// escaping `onSelect`; isolating the builder to the main actor (where its
// view-body callers already are) keeps that capture on a single actor.
@MainActor
@ViewBuilder
func sortMenuButtons(onSelect: @escaping (MoviesSort) -> Void) -> some View {
    Button("Sort by added date") { onSelect(.byAddedDate) }
    Button("Sort by release date") { onSelect(.byReleaseDate) }
    Button("Sort by ratings") { onSelect(.byScore) }
    Button("Sort by popularity") { onSelect(.byPopularity) }
}
