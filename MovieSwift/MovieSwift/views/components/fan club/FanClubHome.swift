//
//  FanClubHome.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 24/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

struct FanClubHome: ConnectedView {
    struct Props {
        let peoples: [Int]
        let popular: [Int]
        let dispatch: DispatchFunction
    }
    
    var embedInNavigationStack = true
    var showNavigationTitle = true
    @State private var currentPage = 1
    #if targetEnvironment(macCatalyst)
    @State private var selectedPeopleId: Int?
    #endif
    
    func map(state: AppState , dispatch: @escaping DispatchFunction) -> Props {
        Props(peoples: state.peoplesState.fanClub.map{ $0 }.sorted(),
              popular: state.peoplesState.popular
                .filter{ !state.peoplesState.fanClub.contains($0) }
                .sorted() { state.peoplesState.peoples[$0]!.name < state.peoplesState.peoples[$1]!.name },
              dispatch: dispatch)
    }
    
    @ViewBuilder
    private func peopleNavigationLink(people: Int) -> some View {
        #if targetEnvironment(macCatalyst)
        Button(action: { selectedPeopleId = people }) {
            PeopleRow(peopleId: people)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftSelectionButtonStyle())
        .focusable()
        #else
        NavigationLink(destination: PeopleDetail(peopleId: people).id(people)) {
            PeopleRow(peopleId: people)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftSelectionButtonStyle())
        #endif
    }
    
    private func listView(props: Props) -> some View {
        List {
            Section {
                ForEach(props.peoples, id: \.self) { people in
                    peopleNavigationLink(people: people)
                }.onDelete(perform: { index in
                    props.dispatch(PeopleActions.RemoveFromFanClub(people: props.peoples[index.first!]))
                })
            }
        
            Section(header: Text("Popular people to add to your Fan Club")) {
                ForEach(props.popular, id: \.self) { people in
                    peopleNavigationLink(people: people)
                }
            }
            
            if !props.popular.isEmpty {
                Rectangle()
                    .foregroundColor(.clear)
                    .onAppear {
                        self.currentPage += 1
                        props.dispatch(PeopleActions.FetchPopular(page: self.currentPage))
                }
            }
        }
        .animation(.spring(), value: props.peoples.count + props.popular.count)
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
        }
        #endif
    }
    
    @ViewBuilder
    private func screen(props: Props) -> some View {
        if showNavigationTitle {
            listView(props: props).navigationTitle("Fan Club")
        } else {
            listView(props: props)
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
        .onAppear {
            if self.currentPage == 1{
                props.dispatch(PeopleActions.FetchPopular(page: self.currentPage))
            }
        }
    }
}

#if DEBUG
struct FanClubHome_Previews: PreviewProvider {
    static var previews: some View {
        FanClubHome()
    }
}
#endif
