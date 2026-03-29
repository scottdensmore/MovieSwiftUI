//
//  DiscoverFilterForm.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum DiscoverFilterFormFetchPolicy {
    static func shouldFetchGenres(genres: [Genre]) -> Bool {
        genres.isEmpty
    }
}

enum DiscoverFilterFormState {
    static func formFilter(selectedDate: Int,
                           selectedGenre: Int,
                           selectedCountry: Int,
                           datesInt: [Int],
                           genres: [Genre]) -> DiscoverFilter? {
        if selectedGenre == 0 && selectedCountry == 0 && selectedDate == 0 {
            return nil
        }

        var startDate: Int?
        var endDate: Int?
        var genre: Int?
        var region: String?

        if selectedDate > 0 {
            startDate = datesInt[selectedDate]
            endDate = startDate! + 9
        }
        if selectedGenre > 0 {
            genre = genres[selectedGenre].id
        }
        if selectedCountry > 0 {
            region = NSLocale.isoCountryCodes[selectedCountry - 1]
        }

        return DiscoverFilter(year: DiscoverFilter.randomYear(),
                              startYear: startDate,
                              endYear: endDate,
                              sort: DiscoverFilter.randomSort(),
                              genre: genre,
                              region: region)
    }

    static func selectedDate(currentFilter: DiscoverFilter?, datesInt: [Int]) -> Int {
        guard let startYear = currentFilter?.startYear,
              let dateIndex = datesInt.firstIndex(of: startYear) else {
            return 0
        }
        return dateIndex
    }

    static func selectedGenre(currentFilter: DiscoverFilter?, genres: [Genre]) -> Int {
        guard let genreId = currentFilter?.genre,
              let genreIndex = genres.firstIndex(where: { $0.id == genreId }) else {
            return 0
        }
        return genreIndex
    }

    static func selectedCountry(currentFilter: DiscoverFilter?) -> Int {
        guard let region = currentFilter?.region,
              let countryIndex = NSLocale.isoCountryCodes.firstIndex(of: region) else {
            return 0
        }
        return countryIndex + 1
    }
}

struct DiscoverFilterSavePlan {
    let filterToSave: DiscoverFilter?
    let activeFilter: DiscoverFilter
}

enum DiscoverFilterFormActionPlan {
    static func savePlan(selectedDate: Int,
                         selectedGenre: Int,
                         selectedCountry: Int,
                         datesInt: [Int],
                         genres: [Genre],
                         fallbackRandomFilter: DiscoverFilter) -> DiscoverFilterSavePlan {
        let filterToSave = DiscoverFilterFormState.formFilter(selectedDate: selectedDate,
                                                              selectedGenre: selectedGenre,
                                                              selectedCountry: selectedCountry,
                                                              datesInt: datesInt,
                                                              genres: genres)
        return DiscoverFilterSavePlan(filterToSave: filterToSave,
                                      activeFilter: filterToSave ?? fallbackRandomFilter)
    }
}

struct DiscoverFilterForm : ConnectedView {
    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    struct Props {
        let dispatch: DispatchFunction
        let currentFilter: DiscoverFilter?
        let genres: [Genre]
        let savedFilters: [DiscoverFilter]
    }

    @Environment(\.presentationMode) var presentationMode
    
    let datesText = ["Random",
                     "1950-1959",
                     "1960-1969",
                     "1970-1979",
                     "1980-1989",
                     "1990-1999",
                     "2000-2009",
                     "2010-2019"]
    let datesInt = [0, 1950, 1960, 1970, 1980, 1990, 2000, 2010]
    
    @State var selectedDate: Int = 0
    @State var selectedGenre: Int = 0
    @State var selectedCountry: Int = 0

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              currentFilter: state.moviesState.discoverFilter,
              genres: state.moviesState.genres,
              savedFilters: state.moviesState.savedDiscoverFilters)
    }
    
    var countries: [String] {
        get {
            var countries: [String] = ["Random"]
            for code in NSLocale.isoCountryCodes {
                let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
                let name = NSLocale(localeIdentifier: "en_US").displayName(forKey: NSLocale.Key.identifier, value: id)!
                countries.append(name)
            }
            return countries
        }
    }
    
    private func syncSelections(currentFilter: DiscoverFilter?, genres: [Genre]) {
        self.selectedDate = DiscoverFilterFormState.selectedDate(currentFilter: currentFilter,
                                                                 datesInt: self.datesInt)
        self.selectedGenre = DiscoverFilterFormState.selectedGenre(currentFilter: currentFilter,
                                                                   genres: genres)
        self.selectedCountry = DiscoverFilterFormState.selectedCountry(currentFilter: currentFilter)
    }

    private func formFilter(genres: [Genre]) -> DiscoverFilter? {
        DiscoverFilterFormState.formFilter(selectedDate: selectedDate,
                                           selectedGenre: selectedGenre,
                                           selectedCountry: selectedCountry,
                                           datesInt: datesInt,
                                           genres: genres)
    }

    private func settingsSection(genres: [Genre]) -> some View {
        Section(header: Text("Filter settings"), content: {
            Picker("Era", selection: $selectedDate) {
                    ForEach(0 ..< self.datesText.count, id: \.self) { index in
                        Text(self.datesText[index]).tag(index)
                    }
            }
            .accessibilityIdentifier("discoverFilter.eraPicker")

            if !genres.isEmpty {
                Picker("Genre", selection: $selectedGenre) {
                        ForEach(0 ..< genres.count, id: \.self) { index in
                            Text(genres[index].name).tag(index)
                        }
                }
                .accessibilityIdentifier("discoverFilter.genrePicker")
            }

            Picker("Country of origin", selection: $selectedCountry) {
                    ForEach(0 ..< self.countries.count, id: \.self) { index in
                        Text(self.countries[index]).tag(index)
                    }
            }
            .accessibilityIdentifier("discoverFilter.countryPicker")
        })
    }
    
    private func buttonsSection(props: Props) -> some View {
        Group {
            Section {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                    let plan = DiscoverFilterFormActionPlan.savePlan(selectedDate: self.selectedDate,
                                                                     selectedGenre: self.selectedGenre,
                                                                     selectedCountry: self.selectedCountry,
                                                                     datesInt: self.datesInt,
                                                                     genres: props.genres,
                                                                     fallbackRandomFilter: DiscoverFilter.randomFilter())
                    if let toSave = plan.filterToSave {
                        props.dispatch(MoviesActions.SaveDiscoverFilter(filter: toSave))
                    }
                    props.dispatch(MoviesActions.SetActiveDiscoverFilter(filter: plan.activeFilter))
                    if !isRunningUISmokeTests {
                        props.dispatch(MoviesActions.ResetRandomDiscover())
                        props.dispatch(MoviesActions.FetchRandomDiscover(filter: plan.activeFilter))
                    }
                }, label: {
                    Text("Save and filter movies")
                        .foregroundColor(.green)
                        .padding(.vertical, 6)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                })
                .accessibilityIdentifier("discoverFilter.saveButton")
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                })
                .accessibilityIdentifier("discoverFilter.cancelButton")
            }
            
            Section {
                Button(action: {
                    self.selectedCountry = 0
                    self.selectedDate = 0
                    self.selectedGenre = 0
                    self.presentationMode.wrappedValue.dismiss()
                    props.dispatch(MoviesActions.ResetRandomDiscover())
                    if !isRunningUISmokeTests {
                        props.dispatch(MoviesActions.FetchRandomDiscover())
                    }
                }, label: {
                    Text("Reset random")
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                })
                .accessibilityIdentifier("discoverFilter.resetButton")
            }
        }
    }
    
    private func savedFiltersSection(props: Props) -> some View {
        Group {
            if !props.savedFilters.isEmpty {
                Section(header: Text("Saved filters"), content: {
                    ForEach(0 ..< props.savedFilters.count, id: \.self) { index in
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                            props.dispatch(MoviesActions.ResetRandomDiscover())
                            props.dispatch(MoviesActions.SetActiveDiscoverFilter(filter: props.savedFilters[index]))
                            props.dispatch(MoviesActions.FetchRandomDiscover(filter: props.savedFilters[index]))
                        }, label: {
                            HStack(spacing: 10) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .foregroundColor(.steam_blue)
                                Text(props.savedFilters[index].toText(genres: props.genres))
                                    .foregroundColor(.primary)
                                    .font(.body)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        })
                        .accessibilityIdentifier("discoverFilter.savedFilter.\(index)")
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button(action: {
                        props.dispatch(MoviesActions.ClearSavedDiscoverFilters())
                    }, label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                            Text("Delete saved filters")
                        }
                        .padding(.vertical, 6)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundColor(.red)
                    })
                    .accessibilityIdentifier("discoverFilter.deleteSavedFiltersButton")
                })
            }
        }
    }
    
    func body(props: Props) -> some View {
        return NavigationStack {
            Form {
                settingsSection(genres: props.genres)
                buttonsSection(props: props)
                savedFiltersSection(props: props)
            }
            .navigationTitle("Discover filter")
            .onAppear {
                self.syncSelections(currentFilter: props.currentFilter, genres: props.genres)
                if DiscoverFilterFormFetchPolicy.shouldFetchGenres(genres: props.genres) {
                    props.dispatch(MoviesActions.FetchGenres())
                }
            }
            .onChange(of: props.genres.count) {
                self.syncSelections(currentFilter: props.currentFilter, genres: props.genres)
            }
        }
    }
}

#Preview {
    DiscoverFilterForm().environmentObject(sampleStore)
}
