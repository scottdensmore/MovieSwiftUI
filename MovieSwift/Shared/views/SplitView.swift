//
//  SplitView.swift
//  MovieSwift
//

import SwiftUI
#if os(macOS)
import AppKit
import CoreSpotlight

// MARK: - MacOS implementation
struct SplitView: View {
    let isRunningUISmokeTests: Bool

    /// The selected sidebar menu. When `UI_TEST_SELECT_MENU` is set in the
    /// environment (e.g. by XCUITest `launchEnvironment`), the initial selection
    /// is driven by that value — working around headless CI where `tap()` on
    /// SwiftUI `List(selection:)` rows does not reliably trigger the binding.
    @State private var selectedMenu: OutlineMenu? = initialMenu()
    @State private var detailPath = NavigationPath()
    /// Bumped every time the user picks a different sidebar menu, used
    /// as the .id of the entire detail NavigationStack so SwiftUI fully
    /// destroys any pushed destinations across menu changes.
    @State private var detailRebuildKey = UUID()
    /// Lifted up from OutlineMoviesMenuList so SplitView can nil it
    /// out before the menu changes — that explicit nil tells
    /// .navigationDestination(item:) to pop its pushed destination
    /// (otherwise the macOS NavigationSplitView column keeps the
    /// pushed view alive even after a full subtree rebuild).
    @State private var detailNavigationRoute: MoviesListNavigationRoute?
    @FocusState private var isSidebarFocused: Bool
    @StateObject private var intentNavigation = IntentNavigationStore.shared
    @State private var spotlightMovieId: SpotlightMovieID?

    /// Identifiable wrapper around a movie id so the Spotlight
    /// result sheet uses `.sheet(item:)` for clean push/dismiss.
    private struct SpotlightMovieID: Identifiable, Equatable {
        let id: Int
    }

    @ViewBuilder
    var body: some View {
        NavigationSplitView {
            // Use a ScrollView + buttons instead of List(selection:) so
            // the macOS sidebar's built-in blue selection rectangle
            // doesn't fight the app's gold accent. Each row renders its
            // own selected state via OutlineRow + a steam-gold tinted
            // background.
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(OutlineMenu.allCases, id: \.self) { menu in
                            // Button gives macOS reliable click handling
                            // (a plain .onTapGesture inside a focusable
                            // ScrollView could be eaten by the parent's
                            // focus machinery). .focusable(false) keeps
                            // these buttons out of the Tab chain so
                            // Tab still hops to the detail pane.
                            Button {
                                if selectedMenu != menu {
                                    // Nil the lifted navigationRoute FIRST so
                                    // SwiftUI's .navigationDestination(item:)
                                    // pops the pushed destination before the
                                    // owning subtree changes. Without this,
                                    // the macOS NavigationSplitView column
                                    // hangs on to the previously-pushed view
                                    // even after a full subtree rebuild.
                                    detailNavigationRoute = nil
                                    // Bumping the key forces the entire
                                    // NavigationStack (and any pushed
                                    // MovieDetail / PeopleDetail / etc.)
                                    // to be destroyed and rebuilt for
                                    // the new menu's content.
                                    detailRebuildKey = UUID()
                                    detailPath = NavigationPath()
                                }
                                selectedMenu = menu
                                isSidebarFocused = true
                            } label: {
                                OutlineRow(item: menu, isSelected: selectedMenu == menu)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(rowBackground(for: menu))
                                            .padding(.horizontal, 6)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .id(menu)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("sidebar.\(menu.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .focusable()
                .focused($isSidebarFocused)
                .focusEffectDisabled()
                .onKeyPress(.downArrow) {
                    moveSelection(offset: 1, scrollProxy: scrollProxy)
                }
                .onKeyPress(.upArrow) {
                    moveSelection(offset: -1, scrollProxy: scrollProxy)
                }
                // Tab / Shift+Tab walks across NavigationSplitView panes.
                // SwiftUI's @FocusState doesn't naturally link the sidebar
                // and detail focus states, so advance AppKit's key view
                // loop directly to land on the first focusable control in
                // the detail column.
                .onKeyPress(.tab, phases: .down) { press in
                    advanceKeyViewLoop(forward: !press.modifiers.contains(.shift))
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "\u{19}"), phases: .down) { _ in
                    advanceKeyViewLoop(forward: false)
                    return .handled
                }
            }
            .navigationTitle("Movies")
            .frame(minWidth: 260, idealWidth: 300)
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selectedMenu {
                    selectedMenu.contentView(isRunningUISmokeTests: isRunningUISmokeTests,
                                             navigationRoute: $detailNavigationRoute)
                        .padding(.leading, selectedMenu == .settings ? 0 : 12)
                } else {
                    Text("Select a section")
                        .foregroundColor(.secondary)
                }
            }
            .id(detailRebuildKey)
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.selectedOutlineMenu, $selectedMenu)
        // App Intents (Spotlight / Siri / Shortcuts) write a
        // pending destination here; route it to the corresponding
        // sidebar menu on the same path the sidebar Button taps
        // use, so any pushed MovieDetail / PeopleDetail pops cleanly.
        .onChange(of: intentNavigation.pendingDestination) { _, destination in
            guard let destination else { return }
            let target: OutlineMenu? = {
                switch destination {
                case .popularMovies: return .popular
                case .discover:      return .discover
                case .fanClub:       return .fanClub
                case .wishlist:      return .myLists
                }
            }()
            if let target, target != selectedMenu {
                detailNavigationRoute = nil
                detailRebuildKey = UUID()
                detailPath = NavigationPath()
                selectedMenu = target
            }
            intentNavigation.consume()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let movieId = MovieSpotlightIndexer.movieId(fromIdentifier: identifier) else {
                return
            }
            spotlightMovieId = SpotlightMovieID(id: movieId)
        }
        .sheet(item: $spotlightMovieId) { wrapper in
            NavigationStack {
                MovieDetail(movieId: wrapper.id)
            }
            .frame(minWidth: 720, idealWidth: 820,
                   minHeight: 720, idealHeight: 820)
        }
    }

    /// macOS-style "active vs. inactive selection" background:
    /// - Focused sidebar with row selected → vibrant steam-gold tint
    /// - Sidebar not focused (e.g. detail view has focus) but row still
    ///   selected → muted secondary gray, matching the system's
    ///   unemphasized selection color
    /// - Row not selected → clear
    private func rowBackground(for menu: OutlineMenu) -> Color {
        guard selectedMenu == menu else { return .clear }
        if isSidebarFocused {
            return Color.steam_gold.opacity(0.22)
        }
        return Color.secondary.opacity(0.16)
    }

    private func advanceKeyViewLoop(forward: Bool) {
        guard let window = NSApp.keyWindow else { return }
        if forward {
            window.selectNextKeyView(nil)
        } else {
            window.selectPreviousKeyView(nil)
        }
    }

    private func moveSelection(offset: Int, scrollProxy: ScrollViewProxy) -> KeyPress.Result {
        let all = OutlineMenu.allCases
        guard !all.isEmpty else { return .ignored }
        let currentIdx = selectedMenu.flatMap { all.firstIndex(of: $0) } ?? 0
        let nextIdx = currentIdx + offset
        guard all.indices.contains(nextIdx) else { return .ignored }
        let next = all[nextIdx]
        selectedMenu = next
        withAnimation(.easeOut(duration: 0.12)) {
            scrollProxy.scrollTo(next, anchor: .center)
        }
        return .handled
    }

    private static func initialMenu() -> OutlineMenu {
        if let menuTitle = ProcessInfo.processInfo.environment["UI_TEST_SELECT_MENU"],
           let menu = OutlineMenu.allCases.first(where: { $0.title == menuTitle }) {
            return menu
        }
        return .popular
    }
}
#endif
