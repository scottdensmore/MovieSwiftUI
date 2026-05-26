import SwiftUI

private struct IsRunningUISmokeTestsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ArchivedStateSizeDescriptionKey: EnvironmentKey {
    // `@Sendable`: an EnvironmentKey default is global state under the
    // Swift 6 mode, so a bare `() -> String` (a non-Sendable function
    // type) is rejected.
    static let defaultValue: @Sendable () -> String = { "0 KB" }
}

extension EnvironmentValues {
    var isRunningUISmokeTests: Bool {
        get { self[IsRunningUISmokeTestsKey.self] }
        set { self[IsRunningUISmokeTestsKey.self] = newValue }
    }

    var archivedStateSizeDescription: @Sendable () -> String {
        get { self[ArchivedStateSizeDescriptionKey.self] }
        set { self[ArchivedStateSizeDescriptionKey.self] = newValue }
    }
}

// MARK: - Focused Values (menu bar ↔ view communication)

#if os(iOS) || os(macOS)
struct SelectedOutlineMenuKey: FocusedValueKey {
    typealias Value = Binding<OutlineMenu?>
}

extension FocusedValues {
    var selectedOutlineMenu: Binding<OutlineMenu?>? {
        get { self[SelectedOutlineMenuKey.self] }
        set { self[SelectedOutlineMenuKey.self] = newValue }
    }
}
#endif
