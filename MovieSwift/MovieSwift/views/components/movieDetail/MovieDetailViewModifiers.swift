import SwiftUI

#if os(macOS)
/// Adds standard macOS keyboard shortcuts to pop a pushed NavigationStack
/// destination: Cmd+[ (native "back" shortcut that matches Safari/Finder)
/// and Escape.
private struct MacBackKeyboardShortcut: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .onExitCommand { dismiss() }
            .background {
                Button(action: { dismiss() }) {
                    EmptyView()
                }
                .keyboardShortcut("[", modifiers: .command)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
    }
}

extension View {
    /// On macOS, enables Cmd+[ and Escape to pop the current pushed
    /// NavigationStack destination. No-op on other platforms.
    func macBackKeyboardShortcut() -> some View {
        modifier(MacBackKeyboardShortcut())
    }
}
#else
extension View {
    func macBackKeyboardShortcut() -> some View { self }
}
#endif

private struct TrackedDetailRowModifier: ViewModifier {
    let id: String
    @Binding var visibleRowIds: Set<String>

    func body(content: Content) -> some View {
        content
            .id(id)
            .onScrollVisibilityChange(threshold: 0.5) { visible in
                if visible {
                    visibleRowIds.insert(id)
                } else {
                    visibleRowIds.remove(id)
                }
            }
    }
}

extension View {
    /// Tags a detail-view row with a stable scroll-anchor id and tracks
    /// whether it's at least 50% on-screen, feeding visibility into
    /// `visibleRowIds` so Tab navigation can skip scrolling when the
    /// focused row is already visible.
    func trackedDetailRow(_ id: String, visibleRowIds: Binding<Set<String>>) -> some View {
        modifier(TrackedDetailRowModifier(id: id, visibleRowIds: visibleRowIds))
    }
}
