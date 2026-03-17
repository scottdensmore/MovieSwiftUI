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

    @State private var selectedPeopleId: Int?
    @State private var showSeeAll = false
    #if targetEnvironment(macCatalyst)
    @FocusState private var focusedPeopleId: Int?
    private let seeAllSentinel = -999
    #endif

    private var peoplesListView: some View {
        List(peoples) { cast in
            PeopleListItem(people: cast) {
                selectedPeopleId = cast.id
            }
        }.navigationBarTitle(title)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                Button(action: {
                    showSeeAll = true
                }) {
                    Text("See all").foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                #if targetEnvironment(macCatalyst)
                .focused($focusedPeopleId, equals: seeAllSentinel)
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(peoples) { cast in
                        PeopleRowItem(people: cast) {
                            selectedPeopleId = cast.id
                        }
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
        }
        .navigationDestination(isPresented: $showSeeAll) {
            peoplesListView
        }
    }
}

struct PeopleListItem: View {
    let people: People
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(people.name)
        .accessibilityValue(people.character ?? people.department ?? "")
        .contextMenu{ PeopleContextMenu(people: people.id) }
    }
}

struct PeopleRowItem: View {
    let people: People
    var onSelect: () -> Void

    #if targetEnvironment(macCatalyst)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        Button(action: onSelect) {
            peopleContent
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(people.name)
        .accessibilityValue(people.character ?? people.department ?? "")
        .accessibilityIdentifier("movieDetail.person.\(people.id)")
        .buttonStyle(.plain)
        #if targetEnvironment(macCatalyst)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) { onSelect(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in onSelect(); return .handled }
        .catalystFocusHighlight(isFocused: isFocused)
        #endif
        .contextMenu { PeopleContextMenu(people: people.id) }
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
