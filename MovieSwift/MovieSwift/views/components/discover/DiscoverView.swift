//
//  DiscoverView.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 19/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend
import UI

enum DiscoverSwipeDecision: Equatable {
    case wishlist
    case seenlist
    case none

    static func from(handler: DraggableCover.EndState) -> DiscoverSwipeDecision {
        switch handler {
        case .left:
            return .wishlist
        case .right:
            return .seenlist
        case .cancelled:
            return .none
        }
    }
}

enum DiscoverSwipeAction: Equatable {
    case wishlist(Int)
    case seenlist(Int)
}

enum DiscoverSwipeActionPlan {
    static func action(for decision: DiscoverSwipeDecision, currentMovieId: Int?) -> DiscoverSwipeAction? {
        guard let currentMovieId else { return nil }
        switch decision {
        case .wishlist:
            return .wishlist(currentMovieId)
        case .seenlist:
            return .seenlist(currentMovieId)
        case .none:
            return nil
        }
    }
}

enum DiscoverFetchPolicy {
    static func shouldFetchRandomMovies(currentMovieCount: Int,
                                        force: Bool,
                                        isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests && (currentMovieCount < 10 || force)
    }
}

enum DiscoverEmptyState {
    static func shouldShow(currentMovie: Movie?) -> Bool {
        currentMovie == nil
    }
}

struct DiscoverEmptyStatePresentation: Equatable {
    let title: String
    let message: String
    let showsRefill: Bool
}

enum DiscoverEmptyStateContent {
    static func presentation(filter: DiscoverFilter?, isRunningUISmokeTests: Bool) -> DiscoverEmptyStatePresentation {
        if filter != nil {
            return DiscoverEmptyStatePresentation(title: "No more discover movies",
                                                 message: "Undo the last action, reset the filter, or refill this queue.",
                                                 showsRefill: !isRunningUISmokeTests)
        }

        return DiscoverEmptyStatePresentation(title: "No more discover movies",
                                             message: "Undo the last action or refill to keep browsing.",
                                             showsRefill: !isRunningUISmokeTests)
    }
}

enum DiscoverUndoState {
    static func canUndo(previousMovie: Int?, isDragging: Bool) -> Bool {
        previousMovie != nil && !isDragging
    }
}

struct DiscoverView: ConnectedView {
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests
    
    // MARK: - Props
    struct Props {
        let movies: [Int]
        let posters: [Int: String]
        let currentMovie: Movie?
        let filter: DiscoverFilter?
        let genres: [Genre]
        let dispatch: DispatchFunction
    }
    
    // MARK: - State vars
    @State private var draggedViewState = DraggableCover.DragState.inactive
    @State private var previousMovie: Int? = nil
    @State private var presentedMovie: Movie? = nil
    @State private var isFilterFormPresented = false
    @State private var willEndPosition: CGSize? = nil
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .soft)
    
    #if targetEnvironment(macCatalyst)
    private let bottomSafeInsetFix: CGFloat = 100
    #else
    private let bottomSafeInsetFix: CGFloat = 20
    #endif
    
    // MARK: - Map State to Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var posters: [Int: String] = [:]
        let movies = state.moviesState.discover
        for movie in movies {
            posters[movie] = state.moviesState.movies[movie]!.poster_path
        }
        return Props(movies: movies,
                     posters: posters,
                     currentMovie: movies.isEmpty ? nil : state.moviesState.movies[movies.reversed()[0]],
                     filter: state.moviesState.discoverFilter,
                     genres: state.moviesState.genres,
                     dispatch: dispatch)
    }
    
    // MARK: - Functions
    private func scaleResistance() -> Double {
        Double(abs(willEndPosition?.width ?? draggedViewState.translation.width) / 6800)
    }
    
    private func dragResistance() -> CGFloat {
        abs(willEndPosition?.width ?? draggedViewState.translation.width) / 12
    }
    
    private func leftZoneResistance() -> CGFloat {
        -draggedViewState.translation.width / 1000
    }
    
    private func rightZoneResistance() -> CGFloat {
        draggedViewState.translation.width / 1000
    }
    
    private func draggableCoverEndGestureHandler(props: Props, handler: DraggableCover.EndState) {
        performDiscoverAction(decision: DiscoverSwipeDecision.from(handler: handler), props: props)
    }

    private func performDiscoverAction(decision: DiscoverSwipeDecision, props: Props) {
        guard let action = DiscoverSwipeActionPlan.action(for: decision,
                                                          currentMovieId: props.currentMovie?.id) else {
            return
        }
        let currentMovieId: Int
        switch action {
        case let .wishlist(movieId):
            currentMovieId = movieId
            props.dispatch(MoviesActions.AddToWishlist(movie: movieId))
        case let .seenlist(movieId):
            currentMovieId = movieId
            props.dispatch(MoviesActions.AddToSeenList(movie: movieId))
        }
        previousMovie = currentMovieId
        hapticFeedback.impactOccurred(intensity: 0.8)
        props.dispatch(MoviesActions.PopRandromDiscover())
        willEndPosition = nil
        fetchRandomMovies(props: props, force: false, filter: props.filter)
    }
    
    private func fetchRandomMovies(props: Props, force: Bool, filter: DiscoverFilter?) {
        if DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: props.movies.count,
                                                       force: force,
                                                       isRunningUISmokeTests: isRunningUISmokeTests) {
            props.dispatch(MoviesActions.FetchRandomDiscover(filter: filter))
        }
    }

    private func primaryActionButton(systemImage: String,
                                     color: Color,
                                     decision: DiscoverSwipeDecision,
                                     accessibilityIdentifier: String,
                                     opacity: Double,
                                     xOffset: CGFloat,
                                     yOffset: CGFloat,
                                     props: Props) -> some View {
        Button(action: {
            self.performDiscoverAction(decision: decision, props: props)
        }, label: {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 1)
                Image(systemName: systemImage)
                    .foregroundColor(color)
            }
            .frame(width: 50, height: 50)
            .padding(12)
            .contentShape(Rectangle())
        })
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier)
        .offset(x: xOffset, y: yOffset)
        .opacity(opacity)
        .animation(.spring(), value: self.draggedViewState.translation)
    }
    
    // MARK: Body views
    private func filterView(props: Props) -> some View {
        return BorderedButton(text: props.filter?.toText(genres: props.genres) ?? "Loading...",
                              systemImageName: "line.horizontal.3.decrease",
                              color: .steam_blue,
                              isOn: false) {
                                self.isFilterFormPresented = true
        }
        .accessibilityIdentifier("discover.filterButton")
    }
    
    private func actionsButtons(props: Props) -> some View {
        ZStack(alignment: .center) {
            if props.currentMovie != nil {
                Text(props.currentMovie!.userTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .font(.FjallaOne(size: 18))
                    .lineLimit(2)
                    .accessibilityIdentifier("discover.currentMovieTitle")
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1.0)
                    .offset(x: 0, y: -15)
                    .animation(.easeInOut, value: self.draggedViewState.isDragging)
                
                primaryActionButton(systemImage: "heart.fill",
                                    color: .pink,
                                    decision: .wishlist,
                                    accessibilityIdentifier: "discover.wishlistButton",
                                    opacity: self.draggedViewState.isDragging ? 0.3 + Double(self.leftZoneResistance()) : 0.8,
                                    xOffset: -70,
                                    yOffset: 0,
                                    props: props)

                primaryActionButton(systemImage: "eye.fill",
                                    color: .green,
                                    decision: .seenlist,
                                    accessibilityIdentifier: "discover.seenlistButton",
                                    opacity: self.draggedViewState.isDragging ? 0.3 + Double(self.rightZoneResistance()) : 0.8,
                                    xOffset: 70,
                                    yOffset: 0,
                                    props: props)
                
                
                Button(action: {
                    self.hapticFeedback.impactOccurred(intensity: 0.5)
                    self.previousMovie = props.currentMovie!.id
                    props.dispatch(MoviesActions.PopRandromDiscover())
                    self.fetchRandomMovies(props: props, force: false, filter: props.filter)
                }, label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.red, lineWidth: 1)
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                    }
                    .frame(width: 50, height: 50)
                    .padding(12)
                    .contentShape(Rectangle())
                })
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("discover.dismissButton")
                    .offset(x: 0, y: 30)
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1)
                    .animation(.spring(), value: self.draggedViewState.isDragging)
                
                Button(action: {
                    props.dispatch(MoviesActions.ResetRandomDiscover())
                    self.fetchRandomMovies(props: props, force: true, filter: nil)
                }, label: {
                    Image(systemName: "arrow.swap")
                        .foregroundColor(.steam_blue)
                })
                    .frame(width: 50, height: 50)
                    .accessibilityIdentifier("discover.resetButton")
                    .offset(x: 60, y: 30)
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1.0)
                    .animation(.spring(), value: self.draggedViewState.isDragging)
            } else if DiscoverEmptyState.shouldShow(currentMovie: props.currentMovie) {
                let presentation = DiscoverEmptyStateContent.presentation(filter: props.filter,
                                                                         isRunningUISmokeTests: isRunningUISmokeTests)
                VStack(spacing: 12) {
                    Text(presentation.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .font(.FjallaOne(size: 18))
                        .accessibilityIdentifier("discover.emptyState")

                    Text(presentation.message)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("discover.emptyStateMessage")

                    if presentation.showsRefill {
                        BorderedButton(text: "Refill discover",
                                       systemImageName: "arrow.clockwise",
                                       color: .steam_blue,
                                       isOn: false) {
                            self.fetchRandomMovies(props: props, force: true, filter: props.filter)
                        }
                        .accessibilityIdentifier("discover.refillButton")
                    }
                }
            }

            Button(action: {
                guard let previousMovie = self.previousMovie else { return }
                props.dispatch(MoviesActions.PushRandomDiscover(movie: previousMovie))
                self.previousMovie = nil
            }, label: {
                Image(systemName: "gobackward").foregroundColor(.steam_blue)
            }) .frame(width: 50, height: 50)
                .accessibilityIdentifier("discover.undoButton")
                .offset(x: -60, y: 30)
                .opacity(DiscoverUndoState.canUndo(previousMovie: self.previousMovie,
                                                   isDragging: self.draggedViewState.isActive) ? 1 : 0)
                .animation(.spring(),
                           value: DiscoverUndoState.canUndo(previousMovie: self.previousMovie,
                                                            isDragging: self.draggedViewState.isActive))
        }
    }
    
    private func swipeHintView(props: Props) -> some View {
        Group {
            if props.currentMovie != nil {
                Text("Swipe left to add to wishlist. Swipe right to add to seenlist.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
    
    private func draggableMovies(props: Props) -> some View {
        ForEach(props.movies, id: \.self) { id in
            Group {
                if props.movies.reversed().firstIndex(of: id) == 0 {
                    presentMovieDetails(
                        DraggableCover(posterPath: DiscoverPosterLookup.posterPath(for: id, posters: props.posters),
                                       gestureViewState: self.$draggedViewState,
                                       onTapGesture: {
                                        self.presentedMovie = props.currentMovie
                        },
                                       willEndGesture: { position in
                                        self.willEndPosition = position
                        },
                                       endGestureHandler: { handler in
                                        self.draggableCoverEndGestureHandler(props: props, handler: handler)
                        })
                    )
                } else {
                    DiscoverCoverImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.posters[id],
                                                                                      size: .medium))
                        .scaleEffect(1.0 - CGFloat(props.movies.reversed().firstIndex(of: id)!) * 0.03 + CGFloat(self.scaleResistance()))
                        .padding(.bottom, CGFloat(props.movies.reversed().firstIndex(of: id)! * 16) - self.dragResistance())
                        .animation(self.draggedViewState.isActive ?
                            .easeIn(duration: 0) :
                            .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0),
                                   value: self.draggedViewState.translation)
                }
            }
        }
    }
    
    @ViewBuilder
    private func presentMovieDetails<Content: View>(_ content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
            .popover(item: self.$presentedMovie,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .bottom) { movie in
                NavigationView {
                    MovieDetail(movieId: movie.id)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .environmentObject(store)
                .frame(minWidth: 760, idealWidth: 860, maxWidth: 980,
                       minHeight: 760, idealHeight: 860, maxHeight: 980)
            }
        #else
        content
            .sheet(item: self.$presentedMovie, onDismiss: {
                self.presentedMovie = nil
            }, content: { movie in
                NavigationView {
                    MovieDetail(movieId: movie.id)
                }.navigationViewStyle(StackNavigationViewStyle())
                    .environmentObject(store)
            })
        #endif
    }
    
    func body(props: Props) -> some View {
        ZStack(alignment: .center) {
            draggableMovies(props: props)
            GeometryReader { reader in
                self.filterView(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).minY + reader.safeAreaInsets.top + 10)
                    .frame(height: 50)
                    .sheet(isPresented: self.$isFilterFormPresented, content: { DiscoverFilterForm().environmentObject(store) })
                self.swipeHintView(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).maxY - reader.safeAreaInsets.bottom - self.bottomSafeInsetFix - 85)
                self.actionsButtons(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).maxY - reader.safeAreaInsets.bottom - self.bottomSafeInsetFix)
            }
        }
        .background(FullscreenMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.currentMovie?.poster_path,
                                                                                              size: .original))
            .allowsHitTesting(false)
            .transition(.opacity)
            .animation(.easeInOut, value: props.currentMovie?.poster_path))
        .onAppear {
            self.hapticFeedback.prepare()
            self.fetchRandomMovies(props: props, force: false, filter: props.filter)
            props.dispatch(MoviesActions.FetchGenres())
        }
    }
}

#if DEBUG
struct DiscoverView_Previews : PreviewProvider {
    static var previews: some View {
        DiscoverView().environmentObject(sampleStore)
    }
}
#endif
