import SwiftUI

extension EnvironmentValues {
    @Entry var isRunningUISmokeTests: Bool = false

    // `@Sendable`: an EnvironmentValues entry is global state under the Swift 6
    // mode, so a bare `() -> String` (a non-Sendable function type) is rejected.
    @Entry var archivedStateSizeDescription: @Sendable () -> String = { "0 KB" }
}

// MARK: - Focused Values (menu bar ↔ view communication)

#if os(iOS) || os(macOS)
extension FocusedValues {
    @Entry var selectedOutlineMenu: Binding<OutlineMenu?>?
}
#endif
