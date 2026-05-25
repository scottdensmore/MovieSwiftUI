import SwiftUI
import UI
import MovieSwiftFluxCore

struct MovieInfoPresentation {
    let yearText: String?
    let runtimeText: String?
    let statusText: String?
    let productionCountryText: String?
}

enum MovieInfoState {
    static func presentation(for movie: Movie) -> MovieInfoPresentation {
        MovieInfoPresentation(yearText: movie.release_date.map { String($0.prefix(4)) },
                              runtimeText: movie.runtime.map {
                                  // Built as a String here (not a SwiftUI Text), so it must
                                  // be localized explicitly or "minutes" never translates.
                                  String(localized: "• \($0) minutes",
                                         comment: "Movie runtime shown in the detail info row; argument is the number of minutes")
                              },
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

#Preview {
    MovieInfoRow(movie: sampleMovie).background(Color.black).environmentObject(sampleStore)
}
