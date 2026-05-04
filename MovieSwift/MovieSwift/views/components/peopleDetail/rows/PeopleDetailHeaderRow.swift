//
//  PeopleDetailHeaderRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

enum PeopleDetailHeaderState {
    static let missingKnownForText = "Known work is not available."

    static func knownForText(for people: People) -> String {
        let text = people.knownForText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text! : missingKnownForText
    }
}

struct PeopleDetailHeaderRow : View {
    let people: People

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                BigPeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: people.profile_path,
                                                                              size: .original))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Known for")
                    .titleStyle()
                    .accessibilityIdentifier("peopleDetail.knownFor")
                if let department = people.known_for_department {
                    Text(department)
                }
                Text(PeopleDetailHeaderState.knownForText(for: people))
                    .foregroundColor(.secondary)
                    .font(.body)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

#Preview {
    PeopleDetailHeaderRow(people: sampleCasts.first!)
}
