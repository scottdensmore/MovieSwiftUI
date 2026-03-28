//
//  CustomListDetail.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 19/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import UI

enum CustomListPresentation {
    static func coverMovie(for list: CustomList, movies: [Int: Movie]) -> Movie? {
        guard let id = list.movies.first else {
            return nil
        }
        return movies[id]
    }

    static func coverBackdropMovie(for list: CustomList, movies: [Int: Movie]) -> Movie? {
        guard let id = list.cover else {
            return nil
        }
        return movies[id]
    }
}

enum CustomListSelection {
    static func toggled(movie: Int, in selectedMovies: Set<Int>) -> Set<Int> {
        var nextSelection = selectedMovies
        if nextSelection.contains(movie) {
            nextSelection.remove(movie)
        } else {
            nextSelection.insert(movie)
        }
        return nextSelection
    }

    static func pendingAddButtonTitle(for selectedMovies: Set<Int>) -> String {
        selectedMovies.isEmpty ? "Cancel" : "Add movies (\(selectedMovies.count))"
    }
}

final class CustomListSearchMovieTextWrapper: SearchTextObservable {
    private var dispatchSearches: ((String, Int) -> Void)?

    init(dispatchSearches: ((String, Int) -> Void)? = nil) {
        self.dispatchSearches = dispatchSearches
        super.init()
    }

    func bindDispatchSearches(_ dispatchSearches: @escaping (String, Int) -> Void) {
        self.dispatchSearches = dispatchSearches
    }

    override func onUpdateTextDebounced(text: String) {
        dispatchSearches?(text, 1)
    }
}

enum CustomListDetailState {
    static func list(listId: Int, customLists: [Int: CustomList]) -> CustomList? {
        customLists[listId]
    }

    static func searchedMovies(searchText: String, searchResults: [String: [Int]]) -> [Int]? {
        guard !searchText.isEmpty else {
            return nil
        }
        return searchResults[searchText]
    }
}

struct CustomListDetail : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let list: CustomList?
        let movies: [Int]
        let searchedMovies: [Int]?
        let movieLookup: [Int: Movie]
    }

    @EnvironmentObject private var store: Store<AppState>
    @State private var searchTextWrapper = CustomListSearchMovieTextWrapper()
    @State private var isSearching = false
    @State private var selectedMovies = Set<Int>()
    @State private var isEditingFormPresented = false
    @State private var selectedMoviesSort = MoviesSort.byReleaseDate
    @State private var isSortActionSheetPresented = false

    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMovieId: Int?
    @FocusState private var focusedMovieId: Int?
    #endif

    let listId: Int

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let list = CustomListDetailState.list(listId: listId,
                                              customLists: state.moviesState.customLists)
        return Props(dispatch: dispatch,
                     list: list,
                     movies: list?.movies.sortedMoviesIds(by: selectedMoviesSort, state: state) ?? [],
                     searchedMovies: CustomListDetailState.searchedMovies(searchText: searchTextWrapper.searchText,
                                                                          searchResults: state.moviesState.search),
                     movieLookup: state.moviesState.movies)
    }
    
    private func navbarButtons(props: Props) -> some View {
        Group {
            if isSearching {
                Button(action: {
                    self.searchTextWrapper.searchText = ""
                    self.isSearching = false
                    if !self.selectedMovies.isEmpty {
                        props.dispatch(MoviesActions.AddMoviesToCustomList(list: self.listId,
                                                                           movies: self.selectedMovies.map { $0 }))
                        self.selectedMovies = Set<Int>()
                    }
                }) {
                    Text(CustomListSelection.pendingAddButtonTitle(for: selectedMovies))
                }
            } else {
                HStack(spacing: 16) {
                    Button(action: {
                        self.isEditingFormPresented = true
                    }) {
                        Image(systemName: "pencil.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.steam_gold)
                    }
                    #if os(macOS)
                    Menu {
                        sortMenuButtons { self.selectedMoviesSort = $0 }
                    } label: {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.steam_gold)
                    }
                    #else
                    Button(action: {
                        self.isSortActionSheetPresented.toggle()
                    }, label: {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.steam_gold)
                    })
                    #endif
                }
            }
        }
    }
    
    #if !os(macOS)
    private var sortActionSheet: ActionSheet {
        ActionSheet.sortActionSheet { (sort) in
            if let sort = sort{
                self.selectedMoviesSort = sort
            }
        }
    }
    #endif
    
    func body(props: Props) -> some View {
        List {
            if let list = props.list {
                if !isSearching {
                    CustomListHeaderRow(sorting: $selectedMoviesSort,
                                        list: list,
                                        coverBackdropMovie: CustomListPresentation.coverBackdropMovie(for: list,
                                                                                                      movies: props.movieLookup))
                }
                SearchField(searchTextWrapper: searchTextWrapper,
                            placeholder: "Search movies to add to your list",
                            isSearching: $isSearching,
                            dismissButtonCallback: {
                                self.selectedMovies = Set<Int>()
                })
                    .listRowInsets(EdgeInsets())
                    .padding(4)
                Group {
                    if isSearching {
                        if props.searchedMovies?.isEmpty == true {
                            Text("No results")
                        } else if props.searchedMovies == nil {
                            Text("Searching...")
                        } else {
                            ForEach(props.searchedMovies!, id: \.self) { movie in
                                HStack {
                                    MovieRow(movieId: movie, displayListImage: false)
                                    Spacer(minLength: 0)
                                    if self.selectedMovies.contains(movie) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.steam_white)
                                            .opacity(0.9)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.selectedMovies = CustomListSelection.toggled(movie: movie,
                                                                                      in: self.selectedMovies)
                                }
                                .listRowBackground(self.selectedMovies.contains(movie) ? Color.steam_selection : Color.clear)
                            }
                        }
                    } else {
                        ForEach(props.movies, id: \.self) { movie in
                            #if os(macOS)
                            MacFocusableLink(id: movie, focusedId: $focusedMovieId) {
                                selectedMovieId = movie
                            } label: {
                                MovieRow(movieId: movie, displayListImage: false)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contextMenu { MovieContextMenu(movieId: movie) }
                            #else
                            NavigationLink(destination: MovieDetail(movieId: movie)) {
                                MovieRow(movieId: movie, displayListImage: false)
                            }
                            .buttonStyle(SoftSelectionButtonStyle())
                            #endif
                        }
                        .onDelete { index in
                            if let first = index.first {
                                props.dispatch(MoviesActions.RemoveMovieFromCustomList(list: self.listId,
                                                                                       movie: props.movies[first]))
                            }
                        }
                    }
                }
            } else {
                Text("List not found")
            }
            
        }
            #if os(macOS)
            .navigationDestination(item: $selectedMovieId) { id in
                MovieDetail(movieId: id)
            }
            .onKeyPress(.escape) { dismiss(); return .handled }
            #endif
            .navigationTitle(isSearching ? "Add Movies" : "")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: navbarButtons(props: props))
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    navbarButtons(props: props)
                }
            }
            #endif
            .edgesIgnoringSafeArea(isSearching ? .leading : .top)
            #if !os(macOS)
            .actionSheet(isPresented: $isSortActionSheetPresented, content: { sortActionSheet })
            #endif
        .sheet(isPresented: $isEditingFormPresented,
                   content: { CustomListForm(editingListId: self.listId).environmentObject(self.store)
            })
        .onAppear {
            searchTextWrapper.bindDispatchSearches { text, page in
                props.dispatch(MoviesActions.FetchSearch(query: text, page: page))
            }
        }
    }
}

#if DEBUG
struct CustomListDetail_Previews : PreviewProvider {
    static var previews: some View {
        NavigationView {
            CustomListDetail(listId: sampleStore.state.moviesState.customLists.first!.key)
                .environmentObject(sampleStore)
        }
    }
}
#endif
