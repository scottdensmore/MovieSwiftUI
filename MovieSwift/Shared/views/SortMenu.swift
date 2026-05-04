import SwiftUI

@ViewBuilder
func sortMenuButtons(onSelect: @escaping (MoviesSort) -> Void) -> some View {
    Button("Sort by added date") { onSelect(.byAddedDate) }
    Button("Sort by release date") { onSelect(.byReleaseDate) }
    Button("Sort by ratings") { onSelect(.byScore) }
    Button("Sort by popularity") { onSelect(.byPopularity) }
}
