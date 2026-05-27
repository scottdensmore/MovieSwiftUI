import Foundation
import Observation

// `@MainActor`: an image cache whose `ImageLoader` values drive SwiftUI
// and are created/read from view bodies on the main actor.
@MainActor
public final class ImageLoaderCache {
    public static let shared = ImageLoaderCache()

    private let loaders: NSCache<NSString, ImageLoader> = NSCache()

    public func loaderFor(path: String?, size: ImageService.Size) -> ImageLoader {
        let key = NSString(string: "\(path ?? "missing")#\(size.rawValue)")
        if let loader = loaders.object(forKey: key) {
            return loader
        } else {
            let loader = ImageLoader(path: path, size: size)
            loaders.setObject(loader, forKey: key)
            return loader
        }
    }

    public func clear() {
        loaders.removeAllObjects()
    }
}

// `@MainActor @Observable`: a SwiftUI-observed image holder. The download
// runs off the main actor (URLSession's async `data(from:)`) and the
// resulting `image` is published back on the main actor.
@MainActor
@Observable
public final class ImageLoader {
    public let path: String?
    public let size: ImageService.Size

    public var image: Data?

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(path: String?, size: ImageService.Size) {
        self.size = size
        self.path = path
        loadImage()
    }

    private func loadImage() {
        guard let poster = path, image == nil else {
            return
        }
        loadTask = Task { [weak self, size] in
            let data = await ImageService.shared.fetchImage(poster: poster, size: size)
            self?.image = data
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
