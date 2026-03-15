//
//  CastRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend

struct MovieCrosslinePeopleRow : View {
    let title: String
    let peoples: [People]

    #if targetEnvironment(macCatalyst)
    @State private var selectedPeopleId: Int?
    @State private var showSeeAll = false
    @FocusState private var focusedPeopleId: Int?
    private let seeAllSentinel = -999
    #endif

    private var peoplesListView: some View {
        List(peoples) { cast in
            PeopleListItem(people: cast)
        }.navigationBarTitle(title)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: seeAllSentinel, focusedId: $focusedPeopleId) {
                    showSeeAll = true
                } label: {
                    Text("See all").foregroundColor(.steam_blue)
                }
                #else
                NavigationLink(destination: peoplesListView,
                               label: {
                    Text("See all").foregroundColor(.steam_blue)
                })
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(peoples) { cast in
                        #if targetEnvironment(macCatalyst)
                        PeopleRowItem(people: cast) {
                            selectedPeopleId = cast.id
                        }
                        #else
                        PeopleRowItem(people: cast)
                        #endif
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
        }
        .navigationDestination(isPresented: $showSeeAll) {
            peoplesListView
        }
        #endif
    }
}

struct PeopleListItem: View {
    let people: People

    var body: some View {
        NavigationLink(destination: PeopleDetail(peopleId: people.id)) {
            HStack {
                PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: people.profile_path,
                                                     size: .cast))
                VStack(alignment: .leading, spacing: 8) {
                    Text(people.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(people.character ?? people.department ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }.contextMenu{ PeopleContextMenu(people: people.id) }
        }
    }
}

struct PeopleRowItem: View {
    let people: People

    #if targetEnvironment(macCatalyst)
    var onSelect: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        #if targetEnvironment(macCatalyst)
        Button(action: { onSelect?() }) {
            peopleContent
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) { onSelect?(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in onSelect?(); return .handled }
        .catalystFocusHighlight(isFocused: isFocused)
        .contextMenu { PeopleContextMenu(people: people.id) }
        #else
        NavigationLink(destination: PeopleDetail(peopleId: people.id)) {
            peopleContent
        }
        #endif
    }

    private var peopleContent: some View {
        VStack(alignment: .center) {
            PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: people.profile_path,
                                                                       size: .cast))
            Text(people.name)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(people.character ?? people.department ?? "")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 100)
        .contextMenu{ PeopleContextMenu(people: people.id) }
    }
}

#if DEBUG
struct CastsRow_Previews : PreviewProvider {
    static var previews: some View {
        MovieCrosslinePeopleRow(title: "Sample", peoples: sampleCasts)
    }
}
#endif
