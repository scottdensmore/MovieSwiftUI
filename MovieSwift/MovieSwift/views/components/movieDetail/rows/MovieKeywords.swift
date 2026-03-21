//
//  MovieKeywords.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 16/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import UI

struct MovieKeywords : View {
    let keywords: [Keyword]

    #if targetEnvironment(macCatalyst)
    @State private var selectedKeyword: Keyword?
    @FocusState private var focusedKeywordId: Int?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords")
                .titleStyle()
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(keywords) { keyword in
                        #if targetEnvironment(macCatalyst)
                        CatalystFocusableLink(id: keyword.id, focusedId: $focusedKeywordId) {
                            selectedKeyword = keyword
                        } label: {
                            RoundedBadge(text: keyword.name, color: .steam_background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                        #else
                        NavigationLink(destination: MovieKeywordList(keyword: keyword)) {
                            RoundedBadge(text: keyword.name, color: .steam_background)
                                .padding(.vertical, 2)
                        }
                        #endif
                    }
                }
                .padding(.leading)
                .padding(.trailing)
                .padding(.vertical, 4)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedKeyword) { keyword in
            MovieKeywordList(keyword: keyword)
        }
        #endif
    }
}

#if DEBUG
struct MovieKeywords_Previews : PreviewProvider {
    static var previews: some View {
        MovieKeywords(keywords: [Keyword(id: 0, name: "Test")])
    }
}
#endif
