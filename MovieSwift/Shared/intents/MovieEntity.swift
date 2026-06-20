//  `AppEntity` representation of a movie so parameterised App Intents
//  (Add to Watchlist / Mark as Seen) can take a movie the user picks in
//  Shortcuts/Siri. The query resolves and suggests movies from the
//  persisted `AppState` (the intent runs outside the app, so it reads the
//  last-archived state rather than the live store); the pure selection
//  logic lives in `MovieEntitySource` for unit testing.

import AppIntents
import MovieSwiftFluxCore

struct MovieEntity: AppEntity, Identifiable {
    let id: Int
    let title: String

    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }

    init(movie: Movie) {
        self.id = movie.id
        self.title = movie.title
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static let defaultQuery = MovieEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }
}

struct MovieEntityQuery: EntityQuery {
    func entities(for identifiers: [MovieEntity.ID]) async throws -> [MovieEntity] {
        let state = AppPersistence.loadState() ?? AppState()
        return MovieEntitySource.movies(for: identifiers, from: state).map(MovieEntity.init(movie:))
    }

    func suggestedEntities() async throws -> [MovieEntity] {
        let state = AppPersistence.loadState() ?? AppState()
        return MovieEntitySource.suggested(from: state).map(MovieEntity.init(movie:))
    }
}
