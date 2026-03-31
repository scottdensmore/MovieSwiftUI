//
//  SplitView.swift
//  MovieSwift
//

import SwiftUI

// MARK: - MacOS implementation
struct SplitView: View {
    let isRunningUISmokeTests: Bool

    /// The selected sidebar menu. When `UI_TEST_SELECT_MENU` is set in the
    /// environment (e.g. by XCUITest `launchEnvironment`), the initial selection
    /// is driven by that value — working around headless CI where `tap()` on
    /// SwiftUI `List(selection:)` rows does not reliably trigger the binding.
    @State private var selectedMenu: OutlineMenu? = initialMenu()

    @ViewBuilder
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMenu) {
                ForEach(OutlineMenu.allCases, id: \.self) { menu in
                    OutlineRow(item: menu, isSelected: selectedMenu == menu)
                        .frame(height: 50)
                        .tag(menu)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("sidebar.\(menu.title)")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Movies")
            .frame(minWidth: 260, idealWidth: 300)
        } detail: {
            if let selectedMenu {
                selectedMenu.contentView(isRunningUISmokeTests: isRunningUISmokeTests)
                    .padding(.leading, selectedMenu == .settings ? 0 : 12)
            } else {
                Text("Select a section")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.selectedOutlineMenu, $selectedMenu)
    }

    private static func initialMenu() -> OutlineMenu {
        if let menuTitle = ProcessInfo.processInfo.environment["UI_TEST_SELECT_MENU"],
           let menu = OutlineMenu.allCases.first(where: { $0.title == menuTitle }) {
            return menu
        }
        return .popular
    }
}
