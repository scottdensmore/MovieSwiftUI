//
//  SettingsForm.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 25/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Foundation
import SwiftUIFlux
import Backend

enum SettingsFormRefreshPolicy {
    static func shouldRefreshMovieMenus(previousRegion: String, selectedRegion: String) -> Bool {
        previousRegion != selectedRegion
    }

    static func menusToRefresh(previousRegion: String, selectedRegion: String) -> [MoviesMenu] {
        guard shouldRefreshMovieMenus(previousRegion: previousRegion,
                                      selectedRegion: selectedRegion) else {
            return []
        }

        return MoviesMenu.allCases
    }
}

enum SettingsFormDebugState {
    static func moviesCount(from movies: [Int: Movie]) -> Int {
        movies.count
    }
}

enum SettingsFormState {
    static func moviesCount(in state: AppState) -> Int {
        SettingsFormDebugState.moviesCount(from: state.moviesState.movies)
    }
}

enum SettingsFormCacheResetPolicy {
    static func clearCachedData(state: AppState,
                                dispatch: @escaping DispatchFunction,
                                clearImageCache: () -> Void = {
                                    ImageLoaderCache.shared.clear()
                                },
                                clearURLCache: () -> Void = {
                                    URLCache.shared.removeAllCachedResponses()
                                },
                                archiveState: (AppState) -> Void = { state in
                                    AppPersistence.archiveNow(state: state)
                                }) {
        let cachedState = AppStateCacheReset.persistentSnapshot(from: state)
        clearImageCache()
        clearURLCache()
        dispatch(AppActions.ClearCachedData())
        archiveState(cachedState)
    }
}

struct SettingsForm : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let debugMoviesCount: Int
    }

    private struct RegionOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    @State var selectedRegionCode: String = AppUserDefaults.region
    @State var alwaysOriginalTitle: Bool = false
    @State private var isClearCacheConfirmationPresented = false
    var embedInNavigationStack = true
    var showNavigationTitle = true
    var onClose: (() -> Void)? = nil
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.archivedStateSizeDescription) private var archivedStateSizeDescription

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              debugMoviesCount: SettingsFormState.moviesCount(in: state))
    }

    private var isModalPresentation: Bool {
        onClose != nil
    }
    
    private var regions: [RegionOption] {
        get {
            var regions: [RegionOption] = []
            for code in NSLocale.isoCountryCodes {
                let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
                if let name = NSLocale(localeIdentifier: "en_US")
                    .displayName(forKey: NSLocale.Key.identifier, value: id) {
                    regions.append(RegionOption(code: code, name: name))
                }
            }
            return regions.sorted { $0.name < $1.name }
        }
    }
    
    func debugInfoView(title: String, info: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(info).font(.body).foregroundColor(.secondary)
        }
    }

    private func loadCurrentPreferences() {
        if regions.contains(where: { $0.code == AppUserDefaults.region }) {
            selectedRegionCode = AppUserDefaults.region
        } else if let firstRegion = regions.first {
            selectedRegionCode = firstRegion.code
        }
        alwaysOriginalTitle = AppUserDefaults.alwaysOriginalTitle
    }

    private func savePreferences(dispatch: DispatchFunction) {
        let previousRegion = AppUserDefaults.region
        AppUserDefaults.region = selectedRegionCode
        AppUserDefaults.alwaysOriginalTitle = alwaysOriginalTitle

        for menu in SettingsFormRefreshPolicy.menusToRefresh(previousRegion: previousRegion,
                                                             selectedRegion: selectedRegionCode) {
            dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func cancelAction() {
        close()
    }

    private func clearCachedData(props: Props) {
        SettingsFormCacheResetPolicy.clearCachedData(state: store.state,
                                                     dispatch: props.dispatch)
    }

    private var originalTitlePreferenceRow: some View {
        Button {
            alwaysOriginalTitle.toggle()
        } label: {
            HStack {
                Text("Always show original title")
                Spacer()
                Toggle("", isOn: $alwaysOriginalTitle)
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("settings.alwaysOriginalTitleToggle")
            }
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.alwaysOriginalTitleRow")
    }

    private func formContent(props: Props) -> some View {
        Form {
            Section(header: Text("Region preferences"),
                    footer: Text("Region is used to display a more accurate movies list"),
                    content: {
                    originalTitlePreferenceRow
                    Picker(selection: $selectedRegionCode,
                           label: Text("Region"),
                           content: {
                            ForEach(regions) { region in
                                Text(region.name).tag(region.code)
                            }
                    })
            })
            Section(header: Text("App data"),
                    footer: Text("Clears cached movies, people, details, and images while keeping your lists and preferences. Backup and restore are not implemented yet."),
                    content: {
                Button(role: .destructive) {
                    isClearCacheConfirmationPresented = true
                } label: {
                    Text("Clear cached data")
                }
                .accessibilityIdentifier("settings.clearCachedDataButton")

                Text("Export my data").foregroundColor(.secondary)
                Text("Backup to iCloud").foregroundColor(.secondary)
                Text("Restore from iCloud").foregroundColor(.secondary)
            })
            
            Section(header: Text("Debug info")) {
                debugInfoView(title: "Movies in state",
                              info: "\(props.debugMoviesCount)")
                debugInfoView(title: "Archived state size",
                              info: archivedStateSizeDescription())

            }
        }
        .onAppear(perform: loadCurrentPreferences)
            .onChange(of: selectedRegionCode) { _, _ in
                if !isModalPresentation {
                    savePreferences(dispatch: props.dispatch)
                }
            }
            .onChange(of: alwaysOriginalTitle) { _, _ in
                if !isModalPresentation {
                    savePreferences(dispatch: props.dispatch)
                }
            }
            .tint(.steam_gold)
            .scrollContentBackground(.hidden)
            .background(Color.steam_background)
            .safeAreaPadding(.horizontal, isModalPresentation ? 0 : 12)
    }
    
    @ViewBuilder
    private func screen(props: Props) -> some View {
        if showNavigationTitle {
            formContent(props: props)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if isModalPresentation {
                        ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: cancelAction)
                    .padding(.horizontal, 6)
                                .accessibilityIdentifier("settings.cancelButton")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                savePreferences(dispatch: props.dispatch)
                                close()
                            }
                            .padding(.horizontal, 6)
                            .accessibilityIdentifier("settings.saveButton")
                        }
                    }
                }
        } else {
            formContent(props: props)
        }
    }
    
    func body(props: Props) -> some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    screen(props: props)
                }
            } else {
                screen(props: props)
            }
        }
        .background(Color.steam_background.ignoresSafeArea())
        .confirmationDialog("Clear cached data?",
                            isPresented: $isClearCacheConfirmationPresented,
                            titleVisibility: .visible) {
            Button("Clear Cached Data", role: .destructive) {
                clearCachedData(props: props)
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes cached movie and people data and clears downloaded image responses, but keeps your lists and preferences.")
        }
    }
}

#if DEBUG
struct SettingsForm_Previews : PreviewProvider {
    static var previews: some View {
        SettingsForm()
            .environmentObject(sampleStore)
    }
}
#endif
