import SwiftUI
import SwiftUIFlux

enum PeopleDetailBiographyState {
    static let deathLabel = "Day of death"

    static func shouldShowBiographyToggle(_ biography: String?) -> Bool {
        guard let biography else {
            return false
        }
        return !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct PeopleDetailBiographyRow : View {
    let biography: String?
    let birthDate: String?
    let deathDate: String?
    let placeOfBirth: String?
    #if os(macOS)
    var focusedItem: FocusState<PeopleDetailFocusTarget?>.Binding?
    #endif
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let biography, PeopleDetailBiographyState.shouldShowBiographyToggle(biography) {
                Text("Biography")
                    .titleStyle()
                    .lineLimit(1)
                Text(biography)
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .lineLimit(isExpanded ? 1000 : 4)
                readMoreButton
            }
            if let birthDate {
                Text("Birthday")
                    .titleStyle()
                    .lineLimit(1)
                Text(birthDate)
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .lineLimit(1)
            }
            if let placeOfBirth {
                Text("Place of birth")
                    .titleStyle()
                    .lineLimit(1)
                Text(placeOfBirth)
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .lineLimit(1)
            }
            if let deathDate {
                Text(PeopleDetailBiographyState.deathLabel)
                    .titleStyle()
                    .lineLimit(1)
                Text(deathDate)
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var readMoreButton: some View {
        #if os(macOS)
        if let focusedItem {
            MacFocusableLink(id: PeopleDetailFocusTarget.readMoreButton,
                             focusedId: focusedItem) {
                withAnimation { isExpanded.toggle() }
            } label: {
                Text(isExpanded ? "Less" : "Read more")
                    .foregroundStyle(Color.steam_blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 2)
        } else {
            plainReadMoreButton
        }
        #else
        plainReadMoreButton
        #endif
    }

    private var plainReadMoreButton: some View {
        Button(action: {
            isExpanded.toggle()
        }) {
            Text(isExpanded ? "Less" : "Read more").foregroundStyle(Color.steam_blue)
        }
    }
}

#Preview {
    PeopleDetailBiographyRow(biography: "Super bio",
                             birthDate: "1985-02-03",
                             deathDate: "2005-02-05",
                             placeOfBirth: "USA")
}
