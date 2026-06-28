import Foundation

/// Turns a stored ISO 3166-1 region code (e.g. "AL", "US") into a
/// human-readable country name for display in the UI. Falls back to the raw
/// code when the current locale can't resolve a name, so the indicator is
/// never blank.
public enum RegionPresentation {
    public static func displayName(forRegionCode code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}
