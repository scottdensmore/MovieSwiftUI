import SwiftUI
import Testing
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

/// Guards the `@Entry`-migrated custom environment values: the macro replaced
/// hand-written `EnvironmentKey` defaults, so pin those defaults so a future
/// edit can't silently change them.
@MainActor
@Suite struct EnvironmentKeysTests {
    /// Pins the `@Entry`-generated defaults so a future edit to the macro
    /// declarations can't silently change them.
    @Test func customEnvironmentValuesKeepTheirDefaults() {
        let environment = EnvironmentValues()

        #expect(environment.isRunningUISmokeTests == false)
        #expect(environment.archivedStateSizeDescription() == "0 KB")
        // Note: `FocusedValues.selectedOutlineMenu`'s default (nil, implicit in
        // the `@Entry` Optional) has no plain-init test path like
        // `EnvironmentValues()`, so it isn't asserted here.
    }
}
