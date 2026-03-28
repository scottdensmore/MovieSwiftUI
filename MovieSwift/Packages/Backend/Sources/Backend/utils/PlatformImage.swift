import SwiftUI

/// A SwiftUI view that creates an `Image` from raw `Data`.
/// This is the only file that bridges platform-specific image initialization.
public struct DataImage: View {
    public let data: Data
    public var renderingMode: Image.TemplateRenderingMode?

    public init(data: Data, renderingMode: Image.TemplateRenderingMode? = nil) {
        self.data = data
        self.renderingMode = renderingMode
    }

    public var body: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .renderingMode(renderingMode)
                .resizable()
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .renderingMode(renderingMode)
                .resizable()
        }
        #endif
    }
}
