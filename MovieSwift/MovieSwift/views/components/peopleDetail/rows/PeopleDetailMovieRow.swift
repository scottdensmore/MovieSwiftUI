import SwiftUI
import Backend
import MovieSwiftFluxCore

enum PeopleDetailMovieRowState {
    static func subtitle(for role: String) -> String? {
        let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct PeopleDetailMovieRow: View {
    let movie: Movie
    let role: String

    let onMovieContextMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.poster_path,
                                                                                size: .small),
                                 posterSize: .small)
                ListImage(movieId: movie.id)
            }.fixedSize()
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                if let subtitle = PeopleDetailMovieRowState.subtitle(for: role) {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier(AccessibilityID.PeopleDetail.movie(movie.id))
        .accessibilityElement(children: .combine)
        .contextMenu { MovieContextMenu(movieId: movie.id, onAction: onMovieContextMenu) }
    }
}

#Preview {
    PeopleDetailMovieRow(movie: sampleMovie, role: "Test", onMovieContextMenu: {

    })
}
