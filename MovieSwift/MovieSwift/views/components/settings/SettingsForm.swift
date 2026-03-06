//
//  SettingsForm.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 25/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Foundation
import Backend

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

        if previousRegion != selectedRegionCode {
            for menu in MoviesMenu.allCases {
                store.dispatch(action: MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
            }
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

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                cancelAction()
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button("Save") {
                savePreferences()
                if isModalPresentation {
                    close()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.steam_gold)
            .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(.ultraThinMaterial)
    }
    
    private var formContent: some View {
        Form {
            Section(header: Text("Region preferences"),
                    footer: Text("Region is used to display a more accurate movies list"),
                    content: {
                    Toggle(isOn: $alwaysOriginalTitle) {
                        Text("Always show original title")
                    }
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
                              info: "\(store.state.moviesState.movies.count)")
                debugInfoView(title: "Archived state size",
                              info: "\(store.state.sizeOfArchivedState())")

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
            .safeAreaInset(edge: .bottom) {
                if isModalPresentation {
                    actionBar
                }
            }
            .safeAreaPadding(.horizontal, isModalPresentation ? 0 : 12)
    }
    
    @ViewBuilder
    private var screen: some View {
        if showNavigationTitle {
            formContent
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
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
    }
}
#endif
