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
    @State private var dragOffset: CGFloat = 0

    private let posterWidth: CGFloat = 260
    private let posterSpacing: CGFloat = 36

    private func goTo(_ index: Int) {
        let clamped = max(0, min(index, posters.count - 1))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            currentIndex = clamped
        }
    }

    private func poster3DView(poster: ImageData, index: Int, carouselHeight: CGFloat) -> some View {
        let rawOffset = CGFloat(index - currentIndex)
        let dragItems = dragOffset / (posterWidth + posterSpacing)
        let offset = rawOffset - dragItems
        let absOffset = abs(offset)

        // Horizontal position: centered image at 0, side images pushed left/right
        let xTranslation = offset * (posterWidth * 0.55 + posterSpacing)

        // Scale: center is 1.0, side items shrink down to ~0.7
        let scale: CGFloat = max(0.65, 1.0 - absOffset * 0.15)

        // 3D rotation: side items tilt inward to create Cover Flow curve
        let rotationY: Double = Double(offset) * -35

        // Opacity fades out for far items
        let opacity: Double = max(0.25, 1.0 - Double(absOffset) * 0.3)

        // Z-index: center on top, side items behind
        let zIndex: Double = 100 - Double(absOffset)

        return BigMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(
            path: poster.file_path,
            size: .medium))
            .frame(width: posterWidth, height: carouselHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(rotationY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.6
            )
            .offset(x: xTranslation)
            .opacity(opacity)
            .zIndex(zIndex)
            .onTapGesture {
                goTo(index)
            }
    }

    private func macCarousel(reader: GeometryProxy) -> some View {
        let carouselHeight = min(reader.size.height * 0.7, 420)

        return VStack(spacing: 20) {
            ZStack {
                ForEach(Array(posters.enumerated()), id: \.element.id) { index, poster in
                    poster3DView(poster: poster, index: index, carouselHeight: carouselHeight)
                }
            }
            .frame(width: reader.size.width, height: carouselHeight + 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let itemWidth = posterWidth + posterSpacing
                        let predicted = value.predictedEndTranslation.width
                        let change = -Int((predicted / itemWidth).rounded())
                        let target = max(0, min(currentIndex + change, posters.count - 1))
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            dragOffset = 0
                            currentIndex = target
                        }
                    }
            )

            // Clickable page indicators
            HStack(spacing: 10) {
                ForEach(0..<posters.count, id: \.self) { index in
                    Button {
                        goTo(index)
                    } label: {
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: index == currentIndex ? 10 : 7,
                                   height: index == currentIndex ? 10 : 7)
                            .animation(.easeInOut(duration: 0.25), value: currentIndex)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel("Go to image \(index + 1)")
                }
            }
        }
        .frame(width: reader.size.width)
        .focusable()
        .focused($isCarouselFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            guard currentIndex > 0 else { return .ignored }
            goTo(currentIndex - 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard currentIndex < posters.count - 1 else { return .ignored }
            goTo(currentIndex + 1)
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
