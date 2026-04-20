//
//  GenresList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum GenresListFetchPolicy {
    static func shouldFetchGenres(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }

    static func actionsToDispatch(isRunningUISmokeTests: Bool) -> [Action] {
        guard shouldFetchGenres(isRunningUISmokeTests: isRunningUISmokeTests) else {
            return []
        }

        return [MoviesActions.FetchGenres()]
    }
}

enum GenresListState {
    static func genres(from state: AppState) -> [Genre] {
        // The reducer prepends a synthetic "Random" genre (id: -1) for the
        // Discover filter. It doesn't belong in the genre browse list
        // because it has no movies backing it.
        state.moviesState.genres.filter { $0.id >= 0 }
    }
}

/// Maps each TMDB genre to an SF Symbol + accent color so the Genres
/// grid reads visually like the rest of the app (which leans on
/// imagery) even though TMDB doesn't ship genre artwork.
enum GenrePresentation {
    static func iconName(for genre: Genre) -> String {
        switch genre.name.lowercased() {
        case "action":            return "flame.fill"
        case "adventure":         return "mountain.2.fill"
        case "animation":         return "sparkles"
        case "comedy":            return "face.smiling.inverse"
        case "crime":             return "exclamationmark.shield.fill"
        case "documentary":       return "doc.text.fill"
        case "drama":             return "theatermasks.fill"
        case "family":            return "figure.2.and.child.holdinghands"
        case "fantasy":           return "wand.and.stars"
        case "history":           return "book.closed.fill"
        case "horror":            return "moon.stars.fill"
        case "music":             return "music.note"
        case "mystery":           return "magnifyingglass"
        case "romance":           return "heart.fill"
        case "science fiction":   return "star.square.fill"
        case "tv movie":          return "tv.fill"
        case "thriller":          return "bolt.fill"
        case "war":               return "shield.lefthalf.filled"
        case "western":           return "mappin.and.ellipse"
        default:                  return "film.fill"
        }
    }

    /// Two-color gradient per genre. Derived from genre.id so the
    /// palette is stable between runs but feels varied across the grid.
    static func gradient(for genre: Genre) -> LinearGradient {
        let palette: [(Color, Color)] = [
            (Color(red: 0.85, green: 0.26, blue: 0.32), Color(red: 0.55, green: 0.08, blue: 0.16)), // red
            (Color(red: 0.95, green: 0.58, blue: 0.21), Color(red: 0.66, green: 0.32, blue: 0.04)), // orange
            (Color(red: 0.97, green: 0.78, blue: 0.26), Color(red: 0.72, green: 0.47, blue: 0.08)), // gold
            (Color(red: 0.35, green: 0.65, blue: 0.42), Color(red: 0.14, green: 0.37, blue: 0.21)), // green
            (Color(red: 0.26, green: 0.55, blue: 0.82), Color(red: 0.09, green: 0.27, blue: 0.52)), // blue
            (Color(red: 0.48, green: 0.34, blue: 0.74), Color(red: 0.25, green: 0.13, blue: 0.48)), // violet
            (Color(red: 0.79, green: 0.36, blue: 0.66), Color(red: 0.49, green: 0.12, blue: 0.39)), // magenta
            (Color(red: 0.35, green: 0.45, blue: 0.52), Color(red: 0.14, green: 0.21, blue: 0.28)), // slate
        ]
        let pair = palette[abs(genre.id) % palette.count]
        return LinearGradient(colors: [pair.0, pair.1],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}

#if os(macOS)
private struct GenreCard: View {
    let genre: Genre
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            GenrePresentation.gradient(for: genre)
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: GenrePresentation.iconName(for: genre))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
                Text(genre.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isHighlighted ? Color.white.opacity(0.9) : Color.white.opacity(0.08),
                        lineWidth: isHighlighted ? 3 : 1)
        )
        .shadow(color: .black.opacity(isHighlighted ? 0.35 : 0.2),
                radius: isHighlighted ? 12 : 6,
                y: isHighlighted ? 6 : 3)
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHighlighted)
    }
}
#endif

struct GenresList: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let genres: [Genre]
    }

    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    #if os(macOS)
    @State private var selectedGenre: Genre?
    @State private var highlightedGenreId: Int?
    @FocusState private var isListFocused: Bool
    #endif

    @ViewBuilder
    func body(props: Props) -> some View {
        #if os(macOS)
        macOSBody(props: props)
        #else
        VStack(spacing: 0) {
            List {
                ForEach(props.genres) { genre in
                    NavigationLink(destination: MoviesGenreList(genre: genre)) {
                        Text(genre.name)
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            for action in GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: isRunningUISmokeTests) {
                props.dispatch(action)
            }
        }
        #endif
    }

    #if os(macOS)
    private static let gridColumnCount: Int = 2

    private func move(_ offset: Int, in genreIds: [Int]) {
        guard !genreIds.isEmpty else { return }
        guard let current = highlightedGenreId,
              let idx = genreIds.firstIndex(of: current) else {
            highlightedGenreId = genreIds.first
            return
        }
        let next = idx + offset
        guard genreIds.indices.contains(next) else { return }
        highlightedGenreId = genreIds[next]
    }

    private func macOSBody(props: Props) -> some View {
        let genreIds = props.genres.map(\.id)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: Self.gridColumnCount)

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(props.genres) { genre in
                        GenreCard(genre: genre,
                                  isHighlighted: highlightedGenreId == genre.id)
                            .id(genre.id)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                highlightedGenreId = genre.id
                                isListFocused = true
                            }
                            .onTapGesture(count: 2) {
                                selectedGenre = genre
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(genre.name)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.rightArrow) {
                move(1, in: genreIds)
                if let id = highlightedGenreId {
                    withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                }
                return .handled
            }
            .onKeyPress(.leftArrow) {
                move(-1, in: genreIds)
                if let id = highlightedGenreId {
                    withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                move(Self.gridColumnCount, in: genreIds)
                if let id = highlightedGenreId {
                    withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                move(-Self.gridColumnCount, in: genreIds)
                if let id = highlightedGenreId {
                    withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                }
                return .handled
            }
            .onKeyPress(.return) {
                if let id = highlightedGenreId,
                   let genre = props.genres.first(where: { $0.id == id }) {
                    selectedGenre = genre
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(characters: .init(charactersIn: " ")) { _ in
                if let id = highlightedGenreId,
                   let genre = props.genres.first(where: { $0.id == id }) {
                    selectedGenre = genre
                    return .handled
                }
                return .ignored
            }
            .onAppear {
                if highlightedGenreId == nil {
                    highlightedGenreId = genreIds.first
                }
                for action in GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: isRunningUISmokeTests) {
                    props.dispatch(action)
                }
            }
            .onChange(of: genreIds) { _, newIds in
                if highlightedGenreId == nil {
                    highlightedGenreId = newIds.first
                }
            }
        }
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
                .macBackKeyboardShortcut()
        }
    }
    #endif

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              genres: GenresListState.genres(from: state))
    }
}

#Preview {
    GenresList()
        .environmentObject(sampleStore)
}
