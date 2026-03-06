//
//  CustomListHeaderRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 08/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend

struct CustomListHeaderRow : View {
    @EnvironmentObject var store: Store<AppState>
    @Binding var sorting: MoviesSort
    
    let listId: Int
    var list: CustomList {
        return store.state.moviesState.customLists[listId]!
    }
    var coverBackdropMovie: Movie? {
        guard let id = list.cover else {
            return nil
        }
        return store.state.moviesState.movies[id]
    }
    
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.name)
                .font(.FjallaOne(size: 40))
                .foregroundColor(.steam_gold)
            Text("\(list.movies.count) movies sorted \(sorting.title())")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
    }
    
    var body: some View {
        Group {
            if coverBackdropMovie != nil {
                ZStack(alignment: .bottomLeading) {
                    MovieTopBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: coverBackdropMovie?.backdrop_path ?? coverBackdropMovie?.poster_path,
                                                                                         size: .original),
                                          height: 200)
                    headerText
                }
                .frame(height: 200)
            } else {
                headerText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .background(Color.clear)
            }
        }
        .listRowInsets(EdgeInsets())
    }
}

#if DEBUG
struct CustomListHeaderRow_Previews : PreviewProvider {
    static var previews: some View {
        CustomListHeaderRow(sorting: .constant(.byAddedDate), listId: 0).environmentObject(sampleStore)
    }
}
#endif
