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
    @FocusState private var focusedPeopleId: Int?
    private let seeAllSentinel = -999
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                Button(action: {
                    onSelectSeeAll()
                }) {
                    Text("See all").foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                #if os(macOS)
                .focused($focusedPeopleId, equals: seeAllSentinel)
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(peoples) { cast in
                        PeopleRowItem(people: cast) {
                            onSelectPeople(cast.id)
                        }
                    }
                }.padding(.leading)
            }
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

    private var presentation: MovieCrosslinePersonPresentation {
        MovieCrosslinePeopleState.presentation(for: people)
    }

    #if os(macOS)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        Button(action: onSelect) {
            peopleContent
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.name)
        .accessibilityValue(presentation.subtitle ?? "")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .buttonStyle(.plain)
        #if os(macOS)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) { onSelect(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in onSelect(); return .handled }
        .macFocusHighlight(isFocused: isFocused)
        #endif
        .contextMenu { PeopleContextMenu(people: people.id) }
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

#if DEBUG
struct CastsRow_Previews : PreviewProvider {
    static var previews: some View {
        MovieCrosslinePeopleRow(title: "Sample",
                                peoples: sampleCasts,
                                onSelectPeople: { _ in },
                                onSelectSeeAll: {})
    }
}
#endif
