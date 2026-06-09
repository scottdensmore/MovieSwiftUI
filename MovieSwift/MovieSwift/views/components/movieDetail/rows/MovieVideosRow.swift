import SwiftUI
import MovieSwiftFluxCore

struct MovieVideoPresentation: Identifiable {
    let video: Video

    var id: String { video.id }
    var name: String { video.name }

    /// Deep-links to the trailer on YouTube — opens the YouTube app when
    /// installed, otherwise Safari. TMDB only returns YouTube video keys
    /// (no direct stream), so a web/app deep-link is the only option that
    /// works identically across iOS, macOS, and tvOS.
    var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(video.key)")
    }

    /// YouTube's public thumbnail endpoint for the video key.
    var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(video.key)/hqdefault.jpg")
    }

    var accessibilityId: String { "movieDetail.video.\(video.id)" }
}

enum MovieVideosState {
    /// Keeps only YouTube-hosted videos and orders them Trailer → Teaser →
    /// everything else, preserving TMDB's original order within each type.
    static func presentations(from videos: [Video]) -> [MovieVideoPresentation] {
        func rank(_ type: String) -> Int {
            switch type {
            case "Trailer": return 0
            case "Teaser": return 1
            default: return 2
            }
        }

        return videos
            .filter { $0.site == "YouTube" }
            .enumerated()
            .sorted { (rank($0.element.type), $0.offset) < (rank($1.element.type), $1.offset) }
            .map { MovieVideoPresentation(video: $0.element) }
            // Only keep videos that produce a valid playback URL, so the
            // rendered cards and the "is the row non-empty" guard always
            // agree.
            .filter { $0.youtubeURL != nil }
    }
}

struct MovieVideosRow: View {
    let videos: [Video]
    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    @Environment(\.openURL) private var openURL
    #endif

    private var presentations: [MovieVideoPresentation] {
        MovieVideosState.presentations(from: videos)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Videos")
                .titleStyle()
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(presentations) { presentation in
                        #if os(macOS)
                        MacFocusableLink(id: .video(presentation.id), focusedId: focusedItem) {
                            if let url = presentation.youtubeURL {
                                openURL(url)
                            }
                        } label: {
                            videoCard(presentation)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Play \(presentation.name)")
                        .accessibilityIdentifier(presentation.accessibilityId)
                        #else
                        if let url = presentation.youtubeURL {
                            Link(destination: url) {
                                videoCard(presentation)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Play \(presentation.name)")
                            .accessibilityIdentifier(presentation.accessibilityId)
                        }
                        #endif
                    }
                }
                .padding(.leading)
            }
            .clipped()
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }

    private func videoCard(_ presentation: MovieVideoPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                AsyncImage(url: presentation.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            Text(presentation.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 240, alignment: .leading)
        }
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MovieVideosRow(videos: [Video(id: "1", name: "Official Trailer",
                                         site: "YouTube", key: "dQw4w9WgXcQ", type: "Trailer"), ],
                          focusedItem: $item)
}
#else
#Preview {
    MovieVideosRow(videos: [Video(id: "1", name: "Official Trailer",
                                  site: "YouTube", key: "dQw4w9WgXcQ", type: "Trailer"), ])
}
#endif
