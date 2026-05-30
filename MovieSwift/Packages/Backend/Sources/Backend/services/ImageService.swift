import Foundation

// Stateless (no stored properties), so safe to share across threads —
// the `shared` singleton requires `Sendable` under the Swift 6 mode.
public final class ImageService: Sendable {
    public static let shared = ImageService()

    public enum Size: String, Sendable {
        case small = "https://image.tmdb.org/t/p/w154/"
        case medium = "https://image.tmdb.org/t/p/w500/"
        case cast = "https://image.tmdb.org/t/p/w185/"
        case original = "https://image.tmdb.org/t/p/original/"

        public func path(poster: String) -> URL {
            return URL(string: rawValue)!.appendingPathComponent(poster)
        }
    }

    public enum ImageError: Error {
        case decodingError
    }

    /// Fetches the raw image data, returning `nil` on any transport error
    /// (matching the previous Combine pipeline's `.catch { Just(nil) }`).
    public func fetchImage(poster: String, size: Size) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: size.path(poster: poster))
            return data
        } catch {
            return nil
        }
    }
}
