import Foundation

/// Namespaced accessors for the app's user-facing preferences.
///
/// These are computed `static var`s rather than `@UserDefault`-wrapped
/// stored statics: under the Swift 6 language mode a stored mutable
/// `static var` is rejected as non-concurrency-safe global state. A
/// computed property has no storage, and `UserDefaults.standard` is
/// itself thread-safe, so reading/writing through it on any thread is
/// safe. The read semantics (`object(forKey:) as? T ?? default`) match
/// the previous `UserDefault` property wrapper exactly. (The wrapper
/// type itself is kept for instance-property use and is unit-tested.)
public enum AppUserDefaults {
    // `public`: the Movies region indicator binds to this key via `@AppStorage`
    // so its caption updates the moment the user changes region in Settings.
    public static let regionKey = "user_region"
    private static let alwaysOriginalTitleKey = "original_title"
    private static let userTMDBAPIKeyKey = "user_tmdb_api_key"
    private static let hasCompletedOnboardingKey = "has_completed_onboarding"

    public static var region: String {
        get { UserDefaults.standard.object(forKey: regionKey) as? String ?? (Locale.current.region?.identifier ?? "US") }
        set { UserDefaults.standard.set(newValue, forKey: regionKey) }
    }

    public static var alwaysOriginalTitle: Bool {
        get { UserDefaults.standard.object(forKey: alwaysOriginalTitleKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: alwaysOriginalTitleKey) }
    }

    /// User-supplied TMDB v3 API key. Empty string means "not set" —
    /// the app falls back to the bundled key (if any) via
    /// `LayeredAPIKeyProvider`. Stored in NSUserDefaults rather than
    /// the Keychain because the value is one the user explicitly
    /// pasted in, scoped to the app's container, and the cost of leak
    /// (their own TMDB quota) is comparatively low.
    public static var userTMDBAPIKey: String {
        get { UserDefaults.standard.object(forKey: userTMDBAPIKeyKey) as? String ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userTMDBAPIKeyKey) }
    }

    /// Whether the user has finished the first-launch onboarding flow.
    /// Set to true when they reach the Ready step and tap "Open
    /// MovieSwift". `OnboardingFlow.shouldShow` re-displays the flow
    /// even when this is true if there's no usable API key, since the
    /// app can't function without one.
    public static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.object(forKey: hasCompletedOnboardingKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }
}
