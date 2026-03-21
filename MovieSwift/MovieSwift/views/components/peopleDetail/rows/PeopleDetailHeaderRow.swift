//
//  PeopleDetailHeaderRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct PeopleDetailHeaderRow : View {
    let people: People
    
    var body: some View {
        HStack(alignment: .top) {
            BigPeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: people.profile_path,
                                                    size: .original))
            VStack(alignment: .leading, spacing: 4) {
                Text("Known for")
                    .titleStyle()
                if people.known_for_department != nil{
                    Text(people.known_for_department!)
                }
                Text(people.knownForText ?? "For now nothing much... or missing data")
                    .foregroundColor(.secondary)
                    .font(.body)
                    .lineLimit(nil)
            }
            .padding(.leading, 8)
                .padding(.top, 8)
        }
    }
}

#if DEBUG
struct PeopleDetailHeaderRow_Previews : PreviewProvider {
    static var previews: some View {
        PeopleDetailHeaderRow(people: sampleCasts.first!)
    }
}
#endif
