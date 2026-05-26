import SwiftUI
import Combine

// `@unchecked Sendable`: the only stored property is an `NSCache`, which
// is documented as thread-safe, and it's never reassigned (`let`). That
// makes the `shared` singleton safe to share across threads under the
// Swift 6 mode even though `NSCache` carries no formal `Sendable`
// conformance.
public final class ImageLoaderCache: @unchecked Sendable {
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

public final class ImageLoader: ObservableObject {
    public let path: String?
    public let size: ImageService.Size

    @Published public var image: Data? = nil
    
    public var cancellable: AnyCancellable?
        
    public init(path: String?, size: ImageService.Size) {
        self.size = size
        self.path = path
        loadImage()
    }
    
    private func loadImage() {
        guard let poster = path, image == nil else {
            return
        }
        cancellable = ImageService.shared.fetchImage(poster: poster, size: size)
            .receive(on: DispatchQueue.main)
            .assign(to: \ImageLoader.image, on: self)
    }
    
    deinit {
        cancellable?.cancel()
    }
}
