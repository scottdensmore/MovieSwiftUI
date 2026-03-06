//
//  MyLists.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

struct MyLists : ConnectedView {
    struct Props {
        let customLists: [CustomList]
        let wishlist: [Int]
        let seenlist: [Int]
    }
    
    // MARK: - Vars
    var embedInNavigationStack = true
    var showNavigationTitle = true
    @EnvironmentObject private var store: Store<AppState>
    @State private var selectedList: Int = 0
    @State private var selectedMoviesSort = MoviesSort.byReleaseDate
    @State private var isSortActionSheetPresented = false
    @State private var isEditingFormPresented = false
    #if targetEnvironment(macCatalyst)
    private struct MovieNav: Hashable { let id: Int }
    private struct CustomListNav: Hashable { let id: Int }
    @State private var selectedMovie: MovieNav?
    @State private var selectedCustomList: CustomListNav?
    #endif
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(customLists: state.moviesState.customLists.compactMap{ $0.value },
              wishlist: state.moviesState.wishlist.map{ $0 }.sortedMoviesIds(by: selectedMoviesSort,
                                                                                state: store.state),
              seenlist: state.moviesState.seenlist.map{ $0 }.sortedMoviesIds(by: selectedMoviesSort,
                                                                                state: store.state))
    }
    
    // MARK: - Dynamic views
    private var sortActionSheet: ActionSheet {
        ActionSheet.sortActionSheet { (sort) in
            if let sort = sort{
                self.selectedMoviesSort = sort
            }
        }
    }
    
    private func customListsSection(props: Props) -> some View {
        Section(header: Text("Custom Lists")) {
            Button(action: {
                self.isEditingFormPresented = true
            }) {
                Text("Create custom list").foregroundColor(.steam_blue)
            }
            ForEach(props.customLists) { list in
                #if targetEnvironment(macCatalyst)
                Button(action: { selectedCustomList = CustomListNav(id: list.id) }) {
                    CustomListRow(list: list)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable(false)
                #else
                NavigationLink(destination: CustomListDetail(listId: list.id)) {
                    CustomListRow(list: list)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let list = props.customLists[index.first!]
                self.store.dispatch(action: MoviesActions.RemoveCustomList(list: list.id))
            }
        }
    }
    
    private func wishlistSection(props: Props) -> some View {
        Section(header: Text("\(props.wishlist.count) movies in wishlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.wishlist, id: \.self) {id in
                #if targetEnvironment(macCatalyst)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable(false)
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.wishlist[index.first!]
                self.store.dispatch(action: MoviesActions.RemoveFromWishlist(movie: movie))

            }
        }
    }

    private func seenSection(props: Props) -> some View {
        Section(header: Text("\(props.seenlist.count) movies in seenlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.seenlist, id: \.self) {id in
                #if targetEnvironment(macCatalyst)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable(false)
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.seenlist[index.first!]
                self.store.dispatch(action: MoviesActions.RemoveFromSeenList(movie: movie))
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
        .listStyle(GroupedListStyle())
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedMovie) { nav in
            MovieDetail(movieId: nav.id)
        }
        .navigationDestination(item: $selectedCustomList) { nav in
            CustomListDetail(listId: nav.id)
        }
        #endif
        .actionSheet(isPresented: $isSortActionSheetPresented, content: { sortActionSheet })
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    self.isSortActionSheetPresented.toggle()
                }, label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                })
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
