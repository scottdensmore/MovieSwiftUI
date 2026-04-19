//
//  MoviePostersCarouselView.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct ImagesCarouselView : View {
    let posters: [ImageData]
    @Binding var selectedPoster: ImageData?

    @State private var currentIndex: Int = 0

    private var selectedPosterId: Binding<String> {
        Binding(
            get: { selectedPoster?.id ?? posters.first?.id ?? "" },
            set: { newValue in
                selectedPoster = posters.first(where: { $0.id == newValue })
            }
        )
    }

    private func posterPage(_ poster: ImageData) -> some View {
        BigMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.file_path,
                                                                           size: .medium))
            .tag(poster.id)
            .padding(.horizontal, 24)
    }

    #if os(macOS)
    @FocusState private var isCarouselFocused: Bool
    @State private var scrollPosition: Int?

    private let posterWidth: CGFloat = 260

    private func goTo(_ index: Int) {
        let clamped = max(0, min(index, posters.count - 1))
        scrollPosition = clamped
        currentIndex = clamped
    }

    private func scrollPoster(poster: ImageData, index: Int, height: CGFloat) -> some View {
        let loader = ImageLoaderCache.shared.loaderFor(path: poster.file_path, size: .medium)
        return BigMoviePosterImage(imageLoader: loader)
            .frame(width: posterWidth, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                let v = phase.value
                let absV = abs(v)
                return content
                    .scaleEffect(phase.isIdentity ? 1.0 : max(0.7, 1.0 - absV * 0.2))
                    .rotation3DEffect(.degrees(Double(v) * -35),
                                      axis: (x: 0, y: 1, z: 0),
                                      anchor: .center,
                                      perspective: 0.6)
                    .opacity(phase.isIdentity ? 1.0 : max(0.3, 1.0 - Double(absV) * 0.35))
            }
            .id(index)
            .onTapGesture { goTo(index) }
    }

    private func macCarousel(reader: GeometryProxy) -> some View {
        let carouselHeight = min(reader.size.height * 0.7, 420)
        let sideInset = max((reader.size.width - posterWidth) / 2, 0)

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(posters.enumerated()), id: \.element.id) { index, poster in
                    scrollPoster(poster: poster, index: index, height: carouselHeight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .contentMargins(.horizontal, sideInset, for: .scrollContent)
        .frame(width: reader.size.width, height: carouselHeight + 40)
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue { currentIndex = newValue }
        }
        .focusable()
        .focused($isCarouselFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            guard currentIndex > 0 else { return .ignored }
            withAnimation { goTo(currentIndex - 1) }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard currentIndex < posters.count - 1 else { return .ignored }
            withAnimation { goTo(currentIndex + 1) }
            return .handled
        }
        .onKeyPress(.escape) {
            selectedPoster = nil
            return .handled
        }
    }
    #endif

    private func carousel(reader: GeometryProxy) -> some View {
        TabView(selection: selectedPosterId) {
            ForEach(posters) { poster in
                posterPage(poster)
            }
        }
        #if os(iOS)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: posters.count > 1 ? .automatic : .never))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
        #endif
        .frame(width: reader.size.width,
               height: min(reader.size.height * 0.8, 460))
    }

    private func closeButton() -> some View {
        Button(action: {
            selectedPoster = nil
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
        .padding()
    }

    private func syncIndex() {
        if let selected = selectedPoster,
           let index = posters.firstIndex(where: { $0.id == selected.id }) {
            currentIndex = index
            #if os(macOS)
            scrollPosition = index
            #endif
        }
    }

    var body: some View {
        if !posters.isEmpty {
            GeometryReader { reader in
                ZStack {
                    Color.black.opacity(0.72)
                        #if !os(macOS)
                        .ignoresSafeArea()
                        #endif
                        .onTapGesture {
                            selectedPoster = nil
                        }

                    VStack(spacing: 20) {
                        Spacer()
                        #if os(macOS)
                        macCarousel(reader: reader)
                        #else
                        carousel(reader: reader)
                        #endif
                        closeButton()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                #if os(macOS)
                .clipped()
                #endif
            }
            .onAppear {
                syncIndex()
                #if os(macOS)
                isCarouselFocused = true
                #endif
            }
            .onChange(of: selectedPoster?.id) { _, newValue in
                syncIndex()
                #if os(macOS)
                if newValue != nil {
                    isCarouselFocused = true
                }
                #endif
            }
        }
    }
}

#Preview {
    ImagesCarouselView(posters: [ImageData(aspect_ratio: 0.666666666666667,
                                                  file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                  height: 720,
                                                  width: 1280),
                                       ImageData(aspect_ratio: 0.666666666666667,
                                                  file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                  height: 720,
                                                  width: 1280),
                                       ImageData(aspect_ratio: 0.666666666666667,
                                                  file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                  height: 720,
                                                  width: 1280),
                                       ImageData(aspect_ratio: 0.666666666666667,
                                                  file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                  height: 720,
                                                  width: 1280)],
                             selectedPoster: .constant(nil))
}
