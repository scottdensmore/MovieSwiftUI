//
//  UserDefaults.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 25/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

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
}
