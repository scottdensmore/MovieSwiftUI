import SwiftUI
import Backend
import MovieSwiftFluxCore

enum PeopleDetailImagesState {
    static func accessibilityIdentifier(for index: Int) -> String {
        AccessibilityID.PeopleDetail.image(index)
    }

    static func accessibilityLabel(for index: Int, total: Int) -> String {
        // Returned as a String and handed to `.accessibilityLabel`, so it
        // must be localized here to reach the catalog.
        String(localized: "Image \(index + 1) of \(total)",
               comment: "Accessibility label for a person's photo in the image carousel; args are the 1-based index and total count")
    }
}

struct PeopleDetailImagesRow: View {
    let images: [ImageData]
    @Binding var selectedPoster: ImageData?
    #if os(macOS)
    var focusedItem: FocusState<PeopleDetailFocusTarget?>.Binding?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Images")
                .titleStyle()
                .padding(.leading)
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 16) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            imageButton(index: index, image: image)
                        }
                    }
                    .padding(.leading)
                }
                .clipped()
                .onChange(of: focusedItem?.wrappedValue) { _, newValue in
                    guard case let .image(path) = newValue else { return }
                    withAnimation {
                        scrollProxy.scrollTo(path, anchor: .center)
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 16) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        imageButton(index: index, image: image)
                    }
                }
                .padding(.leading)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }

    @ViewBuilder
    private func imageButton(index: Int, image: ImageData) -> some View {
        #if os(macOS)
        if let focusedItem = focusedItem {
            let isFocused = focusedItem.wrappedValue == .image(image.filePath)
            MacFocusableLink(id: PeopleDetailFocusTarget.image(image.filePath),
                             focusedId: focusedItem) {
                withAnimation {
                    selectedPoster = image
                }
            } label: {
                PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: image.filePath, size: .cast))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 3)
                    )
                    .shadow(color: isFocused ? Color.accentColor.opacity(0.55) : .clear,
                            radius: isFocused ? 8 : 0)
                    .scaleEffect(isFocused ? 1.06 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isFocused)
            }
            .id(image.filePath)
            .accessibilityIdentifier(PeopleDetailImagesState.accessibilityIdentifier(for: index))
            .accessibilityLabel(PeopleDetailImagesState.accessibilityLabel(for: index, total: images.count))
        } else {
            plainImageButton(index: index, image: image)
        }
        #else
        plainImageButton(index: index, image: image)
        #endif
    }

    private func plainImageButton(index: Int, image: ImageData) -> some View {
        Button(action: {
            withAnimation {
                self.selectedPoster = image
            }
        }) {
            PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: image.filePath, size: .cast))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(PeopleDetailImagesState.accessibilityIdentifier(for: index))
        .accessibilityLabel(PeopleDetailImagesState.accessibilityLabel(for: index, total: images.count))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    // #Preview-only sample fixture; sampleCasts is a non-empty compile-time constant.
    // swiftlint:disable:next force_unwrapping
    PeopleDetailImagesRow(images: sampleCasts.first!.images ?? [], selectedPoster: .constant(nil))
}
