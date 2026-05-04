import SwiftUI
import SwiftUIFlux
import Backend

enum PeopleRowState {
    static func people(for peopleId: Int, from state: AppState) -> People? {
        state.peoplesState.peoples[peopleId]
    }

    static func shouldShowPlaceholder(for people: People?) -> Bool {
        people == nil
    }
}

struct PeopleRow : ConnectedView {
    struct Props {
        let people: People?
        let isInFanClub: Bool
    }
    
    let peopleId: Int
    var isSelected = false
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(people: PeopleRowState.people(for: peopleId, from: state),
              isInFanClub: state.peoplesState.fanClub.contains(peopleId))
    }
    
    private var fanClubIcon: some View {
        Image(systemName: "star.circle")
            .imageScale(.large)
            .foregroundColor(.steam_gold)
            .transition(AnyTransition.scale
                .combined(with: .opacity))
    }
    
    func body(props: Props) -> some View {
        HStack {
            PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.people?.profile_path, size: .cast))
            VStack(alignment: .leading) {
                HStack {
                    if props.isInFanClub {
                        fanClubIcon
                    }
                    Text(props.people?.name ?? "Unknown person")
                        .titleStyle()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .animation(.interpolatingSpring(stiffness: 80, damping: 10), value: props.isInFanClub)
                Text(props.people?.knownForText ?? "")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(height: 40)
            }
            .padding(.leading, 8)
            Spacer(minLength: 0)
        }.padding(.top)
        .padding(.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .redacted(reason: PeopleRowState.shouldShowPlaceholder(for: props.people) ? .placeholder : [])
    }
}

#Preview {
    PeopleRow(peopleId: sampleCasts.first!.id).environmentObject(sampleStore)
}
