import SwiftUI
import Backend
import MovieSwiftFluxCore
#if os(macOS)
import AppKit
#endif

/// Renders a remote image at an arbitrary size without the fixed-aspect
/// portrait framing BigMoviePosterImage bakes in. Used by the carousel
/// so both posters (portrait) and backdrops (landscape) fill the size
/// the carousel computes from each image's aspect ratio.
struct CarouselImageView: View {
    let path: String
    let size: CGSize

    @StateObject private var loader: ImageLoader

    init(path: String, size: CGSize) {
        self.path = path
        self.size = size
        self._loader = StateObject(wrappedValue: ImageLoaderCache.shared.loaderFor(path: path, size: .medium))
    }

    var body: some View {
        Group {
            if let data = loader.image {
                DataImage(data: data, renderingMode: .original)
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().foregroundStyle(.gray)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
    }
}

struct ImagesCarouselView : View {
    let posters: [ImageData]
    @Binding var selectedPoster: ImageData?

    @State private var currentIndex: Int

    init(posters: [ImageData], selectedPoster: Binding<ImageData?>) {
        self.posters = posters
        self._selectedPoster = selectedPoster
        let initialIndex = posters.firstIndex(where: { $0.id == selectedPoster.wrappedValue?.id }) ?? 0
        self._currentIndex = State(initialValue: initialIndex)
    }

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
    @State private var scrollAccumulator: CGFloat = 0
    @State private var scrollMonitor: Any?

    private let posterSpacing: CGFloat = 36
    private let scrollSensitivity: CGFloat = 60  // scroll wheel delta per item step

    /// Width / height of the centered item, derived from the source
    /// images' aspect ratio so posters (portrait) and backdrops
    /// (landscape) both render correctly.
    private func itemSize(in reader: GeometryProxy) -> CGSize {
        let aspect = CGFloat(posters.first?.aspect_ratio ?? 0.666666)
        let maxHeight = min(reader.size.height * 0.7, 420)
        let maxWidth = reader.size.width * 0.55
        let widthFromHeight = maxHeight * aspect
        if widthFromHeight <= maxWidth {
            return CGSize(width: widthFromHeight, height: maxHeight)
        }
        return CGSize(width: maxWidth, height: maxWidth / aspect)
    }

    private func goTo(_ index: Int) {
        let clamped = max(0, min(index, posters.count - 1))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentIndex = clamped
        }
        // Keep the external binding in sync so the caller knows which
        // poster is currently on screen. Dismissing the carousel then
        // preserves the "last viewed" selection for focus restoration.
        let target = posters[clamped]
        if selectedPoster?.id != target.id {
            selectedPoster = target
        }
    }

    private func poster3DView(poster: ImageData, index: Int, size: CGSize) -> some View {
        let rawOffset = CGFloat(index - currentIndex)
        let dragItems = dragOffset / (size.width + posterSpacing)
        let offset = rawOffset - dragItems
        let absOffset = abs(offset)

        let xTranslation = offset * (size.width * 0.55 + posterSpacing)
        let scale: CGFloat = max(0.65, 1.0 - absOffset * 0.15)
        let rotationY: Double = Double(offset) * -35
        let opacity: Double = max(0.25, 1.0 - Double(absOffset) * 0.3)
        let zIndex: Double = 100 - Double(absOffset)

        return CarouselImageView(path: poster.file_path, size: size)
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
            .onTapGesture { goTo(index) }
    }

    private func handleScrollDelta(_ delta: CGFloat) {
        // Positive delta on macOS typically means "moved fingers right"
        // (content moves right = previous item). Invert so right swipe
        // advances forward visually.
        scrollAccumulator -= delta
        while scrollAccumulator >= scrollSensitivity {
            scrollAccumulator -= scrollSensitivity
            if currentIndex < posters.count - 1 {
                goTo(currentIndex + 1)
            }
        }
        while scrollAccumulator <= -scrollSensitivity {
            scrollAccumulator += scrollSensitivity
            if currentIndex > 0 {
                goTo(currentIndex - 1)
            }
        }
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // Only react while the carousel is on-screen.
            guard selectedPoster != nil else { return event }
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let delta = abs(dx) >= abs(dy) ? dx : dy
            if delta != 0 {
                handleScrollDelta(delta)
                return nil  // consume
            }
            return event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
        scrollMonitor = nil
    }

    private func macCarousel(reader: GeometryProxy) -> some View {
        let size = itemSize(in: reader)

        return ZStack {
            ForEach(Array(posters.enumerated()), id: \.element.id) { index, poster in
                poster3DView(poster: poster, index: index, size: size)
            }
        }
        .frame(width: reader.size.width, height: size.height + 40)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let stride = size.width + posterSpacing
                    let predicted = value.predictedEndTranslation.width
                    let change = -Int((predicted / stride).rounded())
                    let target = max(0, min(currentIndex + change, posters.count - 1))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        dragOffset = 0
                        currentIndex = target
                    }
                    let poster = posters[target]
                    if selectedPoster?.id != poster.id {
                        selectedPoster = poster
                    }
                }
        )
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
                .foregroundStyle(.white.opacity(0.95))
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
                installScrollMonitor()
                #endif
            }
            .onDisappear {
                #if os(macOS)
                removeScrollMonitor()
                #endif
            }
            .onChange(of: selectedPoster?.id) { _, newValue in
                syncIndex()
                #if os(macOS)
                if newValue != nil {
                    isCarouselFocused = true
                } else {
                    removeScrollMonitor()
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
