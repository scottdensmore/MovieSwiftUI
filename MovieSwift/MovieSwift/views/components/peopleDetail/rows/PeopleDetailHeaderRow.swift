import SwiftUI
import Backend
import MovieSwiftFluxCore

enum PeopleDetailHeaderState {
    static let missingKnownForText = "Known work is not available."

    static func knownForText(for people: People) -> String {
        let text = people.knownForText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty {
            return text
        }
        return missingKnownForText
    }
}

struct PeopleDetailHeaderRow: View {
    let people: People

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                BigPeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: people.profilePath,
                                                                              size: .original))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Known for")
                    .titleStyle()
                    .accessibilityIdentifier(AccessibilityID.PeopleDetail.knownFor)
                if let department = people.knownForDepartment {
                    Text(department)
                }
                Text(PeopleDetailHeaderState.knownForText(for: people))
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

#Preview {
    // #Preview-only sample fixture; sampleCasts is a non-empty compile-time constant.
    // swiftlint:disable:next force_unwrapping
    PeopleDetailHeaderRow(people: sampleCasts.first!)
}
