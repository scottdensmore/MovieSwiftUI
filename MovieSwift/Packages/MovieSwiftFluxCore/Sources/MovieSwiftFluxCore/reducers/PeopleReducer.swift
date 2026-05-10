import Foundation
import SwiftUIFlux

public func peoplesStateReducer(state: PeoplesState, action: Action) -> PeoplesState {
    var state = state
    switch action {
    case let action as PeopleActions.PopularRequestStarted:
        state.popularLoading = true
        state.popularLoadFailed = false
        if action.page == 1 {
            state.popularInitialLoadCompleted = false
        }

    case let action as PeopleActions.SetMovieCasts:
        state = mergePeople(peoples: action.response.cast, state: state)
        state = mergePeople(peoples: action.response.crew, state: state)
        state.peoplesMovies[action.movie] = Set(action.response.cast.map{ $0.id } + action.response.crew.map{ $0.id })
        // Deduplicate by person id while preserving first-seen order so a person
        // credited multiple times (e.g. writer + director + producer) shows once.
        state.movieCastOrder[action.movie] = appendUnique(ids: action.response.cast.map { $0.id }, to: [])
        state.movieCrewOrder[action.movie] = appendUnique(ids: action.response.crew.map { $0.id }, to: [])
        state.movieCreditsLoaded.insert(action.movie)

        // Populate reverse lookups so MovieDetailPeopleState can resolve
        // character/department per-movie for each cast/crew member. When a
        // person appears more than once (dual roles, multiple departments),
        // concatenate the values so all credits are shown.
        for cast in action.response.cast {
            guard let character = cast.character,
                  !character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            var perMovie = state.casts[cast.id] ?? [:]
            perMovie[action.movie] = appendRole(character, to: perMovie[action.movie], separator: " / ")
            state.casts[cast.id] = perMovie
        }
        for crew in action.response.crew {
            guard let department = crew.department,
                  !department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            var perMovie = state.crews[crew.id] ?? [:]
            perMovie[action.movie] = appendRole(department, to: perMovie[action.movie], separator: ", ")
            state.crews[crew.id] = perMovie
        }

    case let action as PeopleActions.SetSearch:
        if action.page == 1 {
            state.search[action.query] = action.response.results.map{ $0.id }
        } else {
            state.search[action.query]?.append(contentsOf: action.response.results.map{ $0.id })
        }
        state = mergePeople(peoples: action.response.results, state: state)
        
    case let action as PeopleActions.SetPopular:
        if action.page == 1 {
            state.popular = action.response.results.map{ $0.id }
        } else {
            state.popular = appendUnique(ids: action.response.results.map{ $0.id }, to: state.popular)
        }
        state.popularLoading = false
        state.popularInitialLoadCompleted = true
        state.popularLoadFailed = false
        state = mergePeople(peoples: action.response.results, state: state)

    case is PeopleActions.PopularRequestFailed:
        state.popularLoading = false
        state.popularInitialLoadCompleted = true
        state.popularLoadFailed = true
        
    case let action as PeopleActions.SetDetail:
        if let current = state.peoples[action.person.id] {
            var new = action.person
            new.known_for = current.known_for
            new.images = current.images
            state.peoples[action.person.id] = new
        } else {
            state.peoples[action.person.id] = action.person
        }
        state.detailed.insert(action.person.id)
        
    case let action as PeopleActions.SetPeopleCredits:
        state.casts[action.people] = [:]
        state.crews[action.people] = [:]
        if let cast = action.response.cast {
            for meta in cast where meta.character != nil {
                state.casts[action.people]![meta.id] = meta.character!
            }
        }
        
        if let crew = action.response.crew {
            for meta in crew where meta.department != nil {
                state.crews[action.people]![meta.id] = meta.department!
            }
        }
        state.creditsLoaded.insert(action.people)
        
    case let action as PeopleActions.SetImages:
        var people = state.peoples[action.people] ?? placeholderPeople(id: action.people)
        people.images = action.images
        state.peoples[action.people] = people
        state.imagesLoaded.insert(action.people)
        
    case let action as PeopleActions.AddToFanClub:
        state.fanClub.insert(action.people)
        
    case let action as PeopleActions.RemoveFromFanClub:
        state.fanClub.remove(action.people)
        
    default:
        break
    }

    return state
}

private func placeholderPeople(id: Int) -> People {
    People(id: id,
           name: "Unknown person",
           character: nil,
           department: nil,
           profile_path: nil,
           known_for_department: nil,
           known_for: nil,
           also_known_as: nil,
           birthDay: nil,
           deathDay: nil,
           place_of_birth: nil,
           biography: nil,
           popularity: nil,
           images: nil)
}

private func mergePeople(peoples: [People], state: PeoplesState) -> PeoplesState {
    var state = state
    for people in peoples {
        if let current = state.peoples[people.id] {
            var merged = current
            merged.character = people.character ?? current.character
            merged.department = people.department ?? current.department
            merged.known_for = people.known_for ?? current.known_for
            merged.images = people.images ?? current.images
            state.peoples[people.id] = merged
        } else {
            state.peoples[people.id] = people
        }
    }
    return state
}

private func appendUnique(ids: [Int], to current: [Int]) -> [Int] {
    var merged = current
    var known = Set(current)
    for id in ids where known.insert(id).inserted {
        merged.append(id)
    }
    return merged
}

/// Appends `role` to `existing` using `separator`, skipping duplicates.
/// Returns a single-role string if there's no existing value.
private func appendRole(_ role: String, to existing: String?, separator: String) -> String {
    let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let existing = existing, !existing.isEmpty else {
        return trimmed
    }
    // Skip if already present (case-insensitive compare for crew departments).
    let parts = existing.components(separatedBy: separator)
    if parts.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
        return existing
    }
    return existing + separator + trimmed
}
