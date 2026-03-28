//
//  MyLists.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum MyListsPresentation {
    static func customLists(from customLists: [Int: CustomList]) -> [CustomList] {
        customLists.compactMap { $0.value }
    }

    static func sortedMovies(_ movies: [Int], by sort: MoviesSort, state: AppState) -> [Int] {
        movies.sortedMoviesIds(by: sort, state: state)
    }
}

struct MyLists : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let customLists: [CustomList]
        let wishlist: [Int]
        let seenlist: [Int]
        let movieLookup: [Int: Movie]
    }
    
    // MARK: - Vars
    var embedInNavigationStack = true
    var showNavigationTitle = true
    @EnvironmentObject private var store: Store<AppState>
    @State private var selectedList: Int = 0
    @State private var selectedMoviesSort = MoviesSort.byReleaseDate
    @State private var isSortActionSheetPresented = false
    @State private var isEditingFormPresented = false
    #if os(macOS) || targetEnvironment(macCatalyst)
    private struct MovieNav: Hashable { let id: Int }
    private struct CustomListNav: Hashable { let id: Int }
    @State private var selectedMovie: MovieNav?
    @State private var selectedCustomList: CustomListNav?
    #endif
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              customLists: MyListsPresentation.customLists(from: state.moviesState.customLists),
              wishlist: MyListsPresentation.sortedMovies(state.moviesState.wishlist.map { $0 },
                                                         by: selectedMoviesSort,
                                                         state: state),
              seenlist: MyListsPresentation.sortedMovies(state.moviesState.seenlist.map { $0 },
                                                         by: selectedMoviesSort,
                                                         state: state),
              movieLookup: state.moviesState.movies)
    }
    
    // MARK: - Dynamic views
    #if !os(macOS)
    private var sortActionSheet: ActionSheet {
        ActionSheet.sortActionSheet { (sort) in
            if let sort = sort{
                self.selectedMoviesSort = sort
            }
        }
    }
    #endif
    
    private func customListsSection(props: Props) -> some View {
        Section(header: Text("Custom Lists")) {
            Button(action: {
                self.isEditingFormPresented = true
            }) {
                Text("Create custom list").foregroundColor(.steam_blue)
            }
            .accessibilityIdentifier("myLists.createCustomListButton")
            ForEach(props.customLists) { list in
                #if os(macOS) || targetEnvironment(macCatalyst)
                Button(action: { selectedCustomList = CustomListNav(id: list.id) }) {
                    CustomListRow(list: list,
                                  coverMovie: CustomListPresentation.coverMovie(for: list,
                                                                               movies: props.movieLookup))
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedCustomList = CustomListNav(id: list.id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedCustomList = CustomListNav(id: list.id); return .handled }
                #else
                NavigationLink(destination: CustomListDetail(listId: list.id)) {
                    CustomListRow(list: list,
                                  coverMovie: CustomListPresentation.coverMovie(for: list,
                                                                               movies: props.movieLookup))
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let list = props.customLists[index.first!]
                props.dispatch(MoviesActions.RemoveCustomList(list: list.id))
            }
        }
    }
    
    private func wishlistSection(props: Props) -> some View {
        Section(header: Text("\(props.wishlist.count) movies in wishlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.wishlist, id: \.self) {id in
                #if os(macOS) || targetEnvironment(macCatalyst)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedMovie = MovieNav(id: id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedMovie = MovieNav(id: id); return .handled }
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.wishlist[index.first!]
                props.dispatch(MoviesActions.RemoveFromWishlist(movie: movie))

            }
        }
    }

    private func seenSection(props: Props) -> some View {
        Section(header: Text("\(props.seenlist.count) movies in seenlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.seenlist, id: \.self) {id in
                #if os(macOS) || targetEnvironment(macCatalyst)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedMovie = MovieNav(id: id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedMovie = MovieNav(id: id); return .handled }
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.seenlist[index.first!]
                props.dispatch(MoviesActions.RemoveFromSeenList(movie: movie))
            }
        }
    }
    
    private func listView(props: Props) -> some View {
        List {
            customListsSection(props: props)
            
            Picker(selection: $selectedList, label: Text("")) {
                Text("Wishlist").tag(0)
                Text("Seenlist").tag(1)
            }.pickerStyle(SegmentedPickerStyle())
            
            if selectedList == 0 {
                wishlistSection(props: props)
            } else if selectedList == 1 {
                seenSection(props: props)
            }
        }
        #if os(iOS) || os(tvOS)
        .listStyle(GroupedListStyle())
        #endif
        #if os(macOS) || targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedMovie) { nav in
            MovieDetail(movieId: nav.id)
        }
        .navigationDestination(item: $selectedCustomList) { nav in
            CustomListDetail(listId: nav.id)
        }
        #endif
        #if !os(macOS)
        .actionSheet(isPresented: $isSortActionSheetPresented, content: { sortActionSheet })
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                #if os(macOS)
                Menu {
                    sortMenuButtons { self.selectedMoviesSort = $0 }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                }
                #else
                Button(action: {
                    self.isSortActionSheetPresented.toggle()
                }, label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                })
                #endif
            }
        }
    }
    
    @ViewBuilder
    private func screen(props: Props) -> some View {
        if showNavigationTitle {
            listView(props: props).navigationTitle("My Lists")
        } else {
            listView(props: props)
        }
    }
    
    func body(props: Props) -> some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    screen(props: props)
                }
            } else {
                screen(props: props)
            }
        }
        .sheet(isPresented: $isEditingFormPresented) {
                CustomListForm(editingListId: nil).environmentObject(self.store)
        }
    }
}

#if DEBUG
struct MyLists_Previews : PreviewProvider {
    static var previews: some View {
        MyLists().environmentObject(sampleStore)
    }
}
#endif
