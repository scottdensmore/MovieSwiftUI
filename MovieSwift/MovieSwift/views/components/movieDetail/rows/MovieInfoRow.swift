//
//  MovieInfoRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/12/2020.
//  Copyright © 2020 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import UI

struct MovieInfoPresentation {
    let yearText: String?
    let runtimeText: String?
    let statusText: String?
    let productionCountryText: String?
}

enum MovieInfoState {
    static func presentation(for movie: Movie) -> MovieInfoPresentation {
        MovieInfoPresentation(yearText: movie.release_date.map { String($0.prefix(4)) },
                              runtimeText: movie.runtime.map { "• \($0) minutes" },
                              statusText: movie.status.map { "• \($0)" },
                              productionCountryText: movie.production_countries?.first?.name)
    }
}

struct MovieInfoRow : View {
    let movie: Movie

    private var presentation: MovieInfoPresentation {
        MovieInfoState.presentation(for: movie)
    }
    
    var asyncTextTransition: AnyTransition {
        .opacity
    }
    
    var asyncTextAnimation: Animation {
        .easeInOut
    }
    
    private var infos: some View {
        HStack {
            if let yearText = presentation.yearText {
                Text(yearText).font(.subheadline)
            }
            if let runtimeText = presentation.runtimeText {
                Text(runtimeText)
                    .font(.subheadline)
                    .animation(asyncTextAnimation, value: movie.runtime)
                    .transition(asyncTextTransition)
            }
            if let statusText = presentation.statusText {
                Text(statusText)
                    .font(.subheadline)
                    .animation(asyncTextAnimation, value: movie.status)
                    .transition(asyncTextTransition)
            }
        }
        .foregroundColor(.white)
    }
    
    private var productionCountry: some View {
        Group {
            if let productionCountryText = presentation.productionCountryText {
                Text(productionCountryText)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            infos
            productionCountry
        }
    }
}

#if DEBUG
struct MovieInfoRow_Previews : PreviewProvider {
    static var previews: some View {
        MovieInfoRow(movie: sampleMovie).background(Color.black).environmentObject(sampleStore)
    }
}
#endif
