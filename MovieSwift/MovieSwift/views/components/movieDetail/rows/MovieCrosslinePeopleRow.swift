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

struct MovieCrosslinePersonPresentation {
    let name: String
    let subtitle: String?
    let profilePath: String?
    let accessibilityIdentifier: String
}

enum MovieCrosslinePeopleState {
    static func presentation(for people: People) -> MovieCrosslinePersonPresentation {
        MovieCrosslinePersonPresentation(name: people.name,
                                         subtitle: people.character ?? people.department,
                                         profilePath: people.profile_path,
                                         accessibilityIdentifier: "movieDetail.person.\(people.id)")
    }

    static func subtitle(for people: People) -> String {
        presentation(for: people).subtitle ?? ""
    }

    static func accessibilityIdentifier(for people: People) -> String {
        presentation(for: people).accessibilityIdentifier
    }
}

struct MovieCrosslinePeopleRow : View {
    let title: String
    let peoples: [People]
    let onSelectPeople: (Int) -> Void
    let onSelectSeeAll: () -> Void
    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    let personFocusTarget: (Int) -> MovieDetailFocusTarget
    let seeAllFocusTarget: MovieDetailFocusTarget
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                #if os(macOS)
                MacFocusableLink(id: seeAllFocusTarget, focusedId: focusedItem) {
                    onSelectSeeAll()
                } label: {
                    Text("See all").foregroundColor(.steam_blue)
                }
                .padding(.trailing)
                #else
                Button(action: {
                    onSelectSeeAll()
                }) {
                    Text("See all").foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                #endif
            }
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        ForEach(Array(peoples.enumerated()), id: \.offset) { index, cast in
                            PeopleRowItem(people: cast,
                                          onSelect: { onSelectPeople(cast.id) },
                                          focusedItem: focusedItem,
                                          focusTarget: personFocusTarget(cast.id))
                                .id(index)
                        }
                    }.padding(.leading)
                }
                .clipped()
                .onChange(of: focusedItem.wrappedValue) { _, newValue in
                    guard let newValue,
                          let index = peoples.firstIndex(where: { personFocusTarget($0.id) == newValue }) else {
                        return
                    }
                    withAnimation {
                        scrollProxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(Array(peoples.enumerated()), id: \.offset) { _, cast in
                        PeopleRowItem(people: cast) {
                            onSelectPeople(cast.id)
                        }
                    }
                }.padding(.leading)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

struct PeopleListItem: View {
    let people: People
    var onSelect: () -> Void

    private var presentation: MovieCrosslinePersonPresentation {
        MovieCrosslinePeopleState.presentation(for: people)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: presentation.profilePath,
                                                     size: .cast))
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let subtitle = presentation.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.name)
        .accessibilityValue(presentation.subtitle ?? "")
        .contextMenu{ PeopleContextMenu(people: people.id) }
    }
}

struct PeopleRowItem: View {
    let people: People
    var onSelect: () -> Void

    #if os(macOS)
    var focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    var focusTarget: MovieDetailFocusTarget
    #endif

    private var presentation: MovieCrosslinePersonPresentation {
        MovieCrosslinePeopleState.presentation(for: people)
    }

    var body: some View {
        #if os(macOS)
        MacFocusableLink(id: focusTarget, focusedId: focusedItem) {
            onSelect()
        } label: {
            peopleContent
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.name)
        .accessibilityValue(presentation.subtitle ?? "")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .contextMenu { PeopleContextMenu(people: people.id) }
        #else
        Button(action: onSelect) {
            peopleContent
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.name)
        .accessibilityValue(presentation.subtitle ?? "")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .buttonStyle(.plain)
        .contextMenu { PeopleContextMenu(people: people.id) }
        #endif
    }

    private var peopleContent: some View {
        VStack(alignment: .center) {
            PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: presentation.profilePath,
                                                                       size: .cast))
            Text(presentation.name)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(1)
            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 100)
        .contextMenu{ PeopleContextMenu(people: people.id) }
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MovieCrosslinePeopleRow(title: "Sample",
                                   peoples: sampleCasts,
                                   onSelectPeople: { _ in },
                                   onSelectSeeAll: {},
                                   focusedItem: $item,
                                   personFocusTarget: { .castPerson($0) },
                                   seeAllFocusTarget: .castSeeAll)
}
#else
#Preview {
    MovieCrosslinePeopleRow(title: "Sample",
                            peoples: sampleCasts,
                            onSelectPeople: { _ in },
                            onSelectSeeAll: {})
}
#endif
