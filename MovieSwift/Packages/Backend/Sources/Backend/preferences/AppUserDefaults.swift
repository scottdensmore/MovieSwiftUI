import Foundation

public struct AppUserDefaults {
    @UserDefault("user_region", defaultValue: Locale.current.region?.identifier ?? "US")
    public static var region: String

    @UserDefault("original_title", defaultValue: false)
    public static var alwaysOriginalTitle: Bool

    /// User-supplied TMDB v3 API key. Empty string means "not set" —
    /// the app falls back to the bundled key (if any) via
    /// `LayeredAPIKeyProvider`. Stored in NSUserDefaults rather than
    /// the Keychain because the value is one the user explicitly
    /// pasted in, scoped to the app's container, and the cost of leak
    /// (their own TMDB quota) is comparatively low.
    @UserDefault("user_tmdb_api_key", defaultValue: "")
    public static var userTMDBAPIKey: String

    /// Whether the user has finished the first-launch onboarding flow.
    /// Set to true when they reach the Ready step and tap "Open
    /// MovieSwift". `OnboardingFlow.shouldShow` re-displays the flow
    /// even when this is true if there's no usable API key, since the
    /// app can't function without one.
    @UserDefault("has_completed_onboarding", defaultValue: false)
    public static var hasCompletedOnboarding: Bool
}
