import SwiftUI
import MovieSwiftFluxCore

enum PeopleContextMenuFanClubAction: Equatable {
    case add(people: Int)
    case remove(people: Int)

    static func toggleAction(people: Int, isInFanClub: Bool) -> PeopleContextMenuFanClubAction {
        isInFanClub ? .remove(people: people) : .add(people: people)
    }

    static func title(isInFanClub: Bool) -> String {
        isInFanClub ? "Remove from fan club" : "Add to fan club"
    }

    static func systemImageName(isInFanClub: Bool) -> String {
        isInFanClub ? "star.circle.fill" : "star.circle"
    }
}

struct PeopleContextMenu: ConnectedView {

    struct Props {
        let isInFanClub: Bool
        let title: String
        let systemImageName: String
        let toggleFanClub: () -> Void
    }

    let people: Int

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let isInFanClub = state.peoplesState.fanClub.contains(self.people)
        return Props(isInFanClub: isInFanClub,
                     title: PeopleContextMenuFanClubAction.title(isInFanClub: isInFanClub),
                     systemImageName: PeopleContextMenuFanClubAction.systemImageName(isInFanClub: isInFanClub),
                     toggleFanClub: {
                        switch PeopleContextMenuFanClubAction.toggleAction(people: self.people, isInFanClub: isInFanClub) {
                        case let .add(people):
                            dispatch(PeopleActions.AddToFanClub(people: people))
                        case let .remove(people):
                            dispatch(PeopleActions.RemoveFromFanClub(people: people))
                        }
                     })
    }

    func body(props: Props) -> some View {
        VStack {
            Button(action: props.toggleFanClub) {
                HStack {
                    Text(props.title)
                    Image(systemName: props.systemImageName)
                        .imageScale(.medium)
                }
            }
        }
    }
}

#Preview {
    PeopleContextMenu(people: 0).environment(sampleStore)
}
