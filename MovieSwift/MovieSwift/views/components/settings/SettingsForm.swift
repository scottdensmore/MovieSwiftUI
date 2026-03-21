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

struct SettingsForm : View {
    private struct RegionOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    @State var selectedRegionCode: String = AppUserDefaults.region
    @State var alwaysOriginalTitle: Bool = false
    var embedInNavigationStack = true
    var showNavigationTitle = true
    var onClose: (() -> Void)? = nil
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.dismiss) private var dismiss

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

    private func savePreferences() {
        let previousRegion = AppUserDefaults.region
        AppUserDefaults.region = selectedRegionCode
        AppUserDefaults.alwaysOriginalTitle = alwaysOriginalTitle

        for menu in SettingsFormRefreshPolicy.menusToRefresh(previousRegion: previousRegion,
                                                             selectedRegion: selectedRegionCode) {
            store.dispatch(action: MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.alwaysOriginalTitleRow")
    }

    private var formContent: some View {
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
            Section(header: Text("App data"), footer: Text("None of those action are working yet ;)"), content: {
                Text("Export my data")
                Text("Backup to iCloud")
                Text("Restore from iCloud")
                Text("Reset application data").foregroundColor(.red)
            })
            
            Section(header: Text("Debug info")) {
                debugInfoView(title: "Movies in state",
                              info: "\(SettingsFormDebugState.moviesCount(from: store.state.moviesState.movies))")
                debugInfoView(title: "Archived state size",
                              info: appRuntime.archivedStateSizeDescription())

            }
        }
        .onAppear(perform: loadCurrentPreferences)
            .onChange(of: selectedRegionCode) { _, _ in
                if !isModalPresentation {
                    savePreferences()
                }
            }
            .onChange(of: alwaysOriginalTitle) { _, _ in
                if !isModalPresentation {
                    savePreferences()
                }
            }
            .tint(.steam_gold)
            .scrollContentBackground(.hidden)
            .background(Color.steam_background)
            .safeAreaPadding(.horizontal, isModalPresentation ? 0 : 12)
    }
    
    @ViewBuilder
    private var screen: some View {
        if showNavigationTitle {
            formContent
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if isModalPresentation {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel", action: cancelAction)
                                .accessibilityIdentifier("settings.cancelButton")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                savePreferences()
                                close()
                            }
                            .accessibilityIdentifier("settings.saveButton")
                        }
                    }
                }
        } else {
            formContent
        }
    }
    
    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    screen
                }
            } else {
                screen
            }
        }
        .background(Color.steam_background.ignoresSafeArea())
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
