//
//  CustomListForm.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 18/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import UI

final class CustomListFormSearchWrapper: SearchTextObservable {
    private var dispatchSearches: ((String, Int) -> Void)?

    init(dispatchSearches: ((String, Int) -> Void)? = nil) {
        self.dispatchSearches = dispatchSearches
        super.init()
    }

    func bindDispatchSearches(_ dispatchSearches: @escaping (String, Int) -> Void) {
        self.dispatchSearches = dispatchSearches
    }

    override func onUpdateTextDebounced(text: String) {
        if !text.isEmpty {
            dispatchSearches?(text, 1)
        }
    }
}

enum CustomListFormState {
    static func editingValues(editingListId: Int?, customLists: [Int: CustomList]) -> (name: String, cover: Int?)? {
        guard let id = editingListId, let list = customLists[id] else {
            return nil
        }
        return (name: list.name, cover: list.cover)
    }
}

enum CustomListFormPresentation {
    static func coverMovie(coverId: Int?, movies: [Int: Movie]) -> Movie? {
        guard let coverId else {
            return nil
        }
        return movies[coverId]
    }

    static func searchedMovies(searchText: String,
                               searchResults: [String: [Int]],
                               movies: [Int: Movie]) -> [Movie] {
        guard !searchText.isEmpty else {
            return []
        }
        return (searchResults[searchText] ?? []).compactMap { movies[$0] }
    }
}

struct CustomListForm : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let customLists: [Int: CustomList]
        let customListsCount: Int
        let searchedMovies: [Movie]
        let coverMovie: Movie?
    }

    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchTextWrapper = CustomListFormSearchWrapper()
    @State private var isSearching = false
    @State var listName: String = ""
    @State var listMovieCover: Int?
    
    let editingListId: Int?

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              customLists: state.moviesState.customLists,
              customListsCount: state.moviesState.customLists.count,
              searchedMovies: CustomListFormPresentation.searchedMovies(searchText: searchTextWrapper.searchText,
                                                                       searchResults: state.moviesState.search,
                                                                       movies: state.moviesState.movies),
              coverMovie: CustomListFormPresentation.coverMovie(coverId: listMovieCover,
                                                                movies: state.moviesState.movies))
    }
    
    private var topSection: some View {
        Section(header: Text("List information"),
                content: {
                    HStack {
                        Text("Name:")
                        TextField("Name your list", text: $listName)
                            .accessibilityIdentifier("customListForm.nameField")
                    }
        })
    }
    
    private func coverSection(props: Props) -> some View {
        Section(header: Text("List cover")) {
            if listMovieCover == nil {
                SearchField(searchTextWrapper: searchTextWrapper,
                            placeholder: "Search and add a movie as your cover",
                            isSearching: $isSearching)
                .scrollDismissesKeyboard(.interactively)
            }
            if listMovieCover != nil {
                if let movie = props.coverMovie {
                    CustomListCoverRow(movie: movie)
                }
                Button(action: {
                    self.listMovieCover = nil
                }, label: {
                    Text("Remove cover").foregroundColor(.red)
                })
            }
            
            if !searchTextWrapper.searchText.isEmpty {
                movieSearchSection(props: props)
            }
        }
    }
    
    private func movieSearchSection(props: Props) -> some View {
        Section() {
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(props.searchedMovies) { movie in
                        CustomListCoverRow(movie: movie).onTapGesture {
                            self.listMovieCover = movie.id
                            self.searchTextWrapper.searchText = ""
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .frame(height: 200)
            .padding(.leading, 16)
            .listRowInsets(EdgeInsets())
        }
    }
    
    private func buttonsSection(props: Props) -> some View {
        Section {
            Button(action: {
                let newList = CustomList(id: Int.random(in: props.customListsCount ..< 1000^3),
                                         name: self.listName,
                                         cover: self.listMovieCover,
                                         movies: [])
                if let id = self.editingListId {
                    props.dispatch(MoviesActions.EditCustomList(list: id,
                                                                title: self.listName,
                                                                cover: self.listMovieCover))
                } else {
                    props.dispatch(MoviesActions.AddCustomList(list: newList))
                }
                self.presentationMode.wrappedValue.dismiss()

            }, label: {
                Text(self.editingListId != nil ? "Save changes" : "Create").foregroundColor(.blue)
            })
            .accessibilityIdentifier("customListForm.createButton")
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Cancel").foregroundColor(.red)
            })
            .accessibilityIdentifier("customListForm.cancelButton")
        }
    }
    
    func body(props: Props) -> some View {
        NavigationStack {
            Form {
                topSection
                coverSection(props: props)
                buttonsSection(props: props)
            }
            .navigationTitle("New list")
        }
        .onAppear() {
            searchTextWrapper.bindDispatchSearches { text, page in
                props.dispatch(MoviesActions.FetchSearch(query: text, page: page))
            }
            if let editingValues = CustomListFormState.editingValues(editingListId: self.editingListId,
                                                                     customLists: props.customLists) {
                self.listMovieCover = editingValues.cover
                self.listName = editingValues.name
            }
        }
    }
}

#Preview {
    CustomListForm(editingListId: nil).environmentObject(sampleStore)
}
