import Foundation
import SwiftUI

extension Color {
    public static var steam_white: Color {
        Color("steam_white", bundle: nil)
    }

    public static var steam_gold: Color {
        Color("steam_gold", bundle: nil)
    }

    public static var steam_rust: Color {
        Color("steam_rust", bundle: nil)
    }

    public static var steam_rust2: Color {
        Color("steam_rust2", bundle: nil)
    }

    public static var steam_bronze: Color {
        Color("steam_bronze", bundle: nil)
    }

    public static var steam_brown: Color {
        Color("steam_brown", bundle: nil)
    }

    public static var steam_yellow: Color {
        Color("steam_yellow", bundle: nil)
    }

    public static var steam_blue: Color {
        Color("steam_blue", bundle: nil)
    }

    public static var steam_bordeaux: Color {
        Color("steam_bordeaux", bundle: nil)
    }

    public static var steam_green: Color {
        Color("steam_green", bundle: nil)
    }

    public static var steam_background: Color {
        Color("steam_background", bundle: nil)
    }

    public static var steam_selection: Color {
        Color.steam_white.opacity(0.12)
    }
}

extension View {
    func softSelectionRow(_ isSelected: Bool,
                          cornerRadius: CGFloat = 10) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.steam_selection : .clear)
        )
    }
}

struct SoftSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .softSelectionRow(configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if os(macOS)
/// Replaces SwiftUI's default blue focus ring with a sidebar-style
/// rounded-rectangle highlight on macOS.
struct MacFocusHighlight: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.steam_white.opacity(0.10) : .clear)
            )
            .shadow(color: isFocused ? Color.steam_white.opacity(0.16) : .clear,
                    radius: 14,
                    x: 0,
                    y: 0)
            .shadow(color: isFocused ? Color.black.opacity(0.18) : .clear,
                    radius: 6,
                    x: 0,
                    y: 4)
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isFocused)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isFocused ? Color.black.opacity(0.12) : .clear)
            )
            .focusEffectDisabled()
    }
}

extension View {
    func macFocusHighlight(isFocused: Bool) -> some View {
        self.modifier(MacFocusHighlight(isFocused: isFocused))
    }
}

/// A reusable wrapper that provides a focusable, keyboard-navigable
/// Button for macOS list rows.
struct MacFocusableLink<Label: View, ID: Hashable>: View {
    let id: ID
    var focusedId: FocusState<ID?>.Binding
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focusedId, equals: id)
        .onKeyPress(.return) { action(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in action(); return .handled }
        .macFocusHighlight(isFocused: focusedId.wrappedValue == id)
    }
}
#endif
