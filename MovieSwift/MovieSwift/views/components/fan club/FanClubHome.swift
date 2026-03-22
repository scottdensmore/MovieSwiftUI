//
//  FanClubHome.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 24/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum FanClubState {
    static func fanClubPeople(from state: AppState) -> [Int] {
        state.peoplesState.fanClub.map { $0 }.sorted()
    }

    static func popularPeople(from state: AppState) -> [Int] {
        state.peoplesState.popular
            .filter { !state.peoplesState.fanClub.contains($0) }
            .filter { state.peoplesState.peoples[$0] != nil }
            .sorted { (state.peoplesState.peoples[$0]?.name ?? "") < (state.peoplesState.peoples[$1]?.name ?? "") }
    }
}

enum FanClubPaginationPolicy {
    static func initialPopularPage(popularCount: Int, nextPage: Int) -> Int? {
        guard popularCount == 0, nextPage == 1 else {
            return nil
        }
        return nextPage
    }

    static func nextPopularPage(popular: [Int], lastTriggeredPopularId: Int?, nextPage: Int) -> Int? {
        guard let lastPopularId = popular.last,
              lastTriggeredPopularId != lastPopularId else {
            return nil
        }
        return nextPage
    }
}

enum FanClubPresentation {
    struct EmptyState {
        let title: String
        let message: String
        let accessibilityIdentifier: String
    }

    static func emptyState(peoples: [Int], popular: [Int], hasRequestedInitialPopularPage: Bool) -> EmptyState? {
        guard peoples.isEmpty, popular.isEmpty else {
            return nil
        }

        if hasRequestedInitialPopularPage {
            return EmptyState(title: "No popular people right now",
                              message: "Try again later to find people to add to your Fan Club.",
                              accessibilityIdentifier: "fanClub.emptyState")
        }

        return EmptyState(title: "Loading people",
                          message: "Fetching popular people for your Fan Club.",
                          accessibilityIdentifier: "fanClub.loadingState")
    }
}

struct FanClubHome: ConnectedView {
    struct Props {
        let peoples: [Int]
        let popular: [Int]
        let dispatch: DispatchFunction
    }
    
    var embedInNavigationStack = true
    var showNavigationTitle = true
    @State private var nextPopularPage = 1
    @State private var lastTriggeredPopularId: Int?
    @State private var hasRequestedInitialPopularPage = false
    #if targetEnvironment(macCatalyst)
    @State private var selectedPeopleId: Int?
    @FocusState private var focusedPeopleId: Int?
    #endif
    
    func map(state: AppState , dispatch: @escaping DispatchFunction) -> Props {
        Props(peoples: FanClubState.fanClubPeople(from: state),
              popular: FanClubState.popularPeople(from: state),
              dispatch: dispatch)
    }
    
    @ViewBuilder
    private func peopleNavigationLink(people: Int) -> some View {
        #if targetEnvironment(macCatalyst)
        CatalystFocusableLink(id: people, focusedId: $focusedPeopleId) {
            selectedPeopleId = people
        } label: {
            PeopleRow(peopleId: people)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("fanClub.person.\(people)")
        #else
        NavigationLink(destination: PeopleDetail(peopleId: people).id(people)) {
            PeopleRow(peopleId: people)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SoftSelectionButtonStyle())
        .accessibilityIdentifier("fanClub.person.\(people)")
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
            
            if let lastPopularId = props.popular.last {
                Rectangle()
                    .foregroundColor(.clear)
                    .onAppear {
                        fetchNextPopularPageIfNeeded(props: props, lastPopularId: lastPopularId)
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

    private func emptyStateView(_ state: FanClubPresentation.EmptyState) -> some View {
        VStack(spacing: 12) {
            Text(state.title)
                .font(.headline)
            Text(state.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(state.accessibilityIdentifier)
    }

    @ViewBuilder
    private func screen(props: Props) -> some View {
        let content = Group {
            if let emptyState = FanClubPresentation.emptyState(peoples: props.peoples,
                                                               popular: props.popular,
                                                               hasRequestedInitialPopularPage: hasRequestedInitialPopularPage) {
                emptyStateView(emptyState)
            } else {
                listView(props: props)
            }
        }

        if showNavigationTitle {
            content.navigationTitle("Fan Club")
        } else {
            content
        }
    }

    private func fetchInitialPopularPageIfNeeded(props: Props) {
        guard let page = FanClubPaginationPolicy.initialPopularPage(popularCount: props.popular.count,
                                                                    nextPage: nextPopularPage) else {
            return
        }
        hasRequestedInitialPopularPage = true
        nextPopularPage += 1
        props.dispatch(PeopleActions.FetchPopular(page: page))
    }

    private func fetchNextPopularPageIfNeeded(props: Props, lastPopularId: Int) {
        guard let page = FanClubPaginationPolicy.nextPopularPage(popular: props.popular,
                                                                 lastTriggeredPopularId: lastTriggeredPopularId,
                                                                 nextPage: nextPopularPage) else {
            return
        }
        lastTriggeredPopularId = lastPopularId
        nextPopularPage += 1
        props.dispatch(PeopleActions.FetchPopular(page: page))
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
            fetchInitialPopularPageIfNeeded(props: props)
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
