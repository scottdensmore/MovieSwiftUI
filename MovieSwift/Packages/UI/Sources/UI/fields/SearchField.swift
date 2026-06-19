import SwiftUI
import Combine

// The iOS 13 / macOS 10.15 availability gate is dropped — the package's
// minimum is far past it. The tvOS/watchOS `unavailable` gates remain:
// SearchField is intentionally excluded on those platforms.
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct SearchField: View {
    @ObservedObject var searchTextWrapper: SearchTextObservable
    let placeholder: String
    @Binding var isSearching: Bool
    var dismissButtonTitle: String
    var dismissButtonCallback: (() -> Void)?
    var focused: FocusState<Bool>.Binding?

    public init(searchTextWrapper: SearchTextObservable,
         placeholder: String,
         isSearching: Binding<Bool>,
         dismissButtonTitle: String = "Cancel",
         dismissButtonCallback: (() -> Void)? = nil,
         focused: FocusState<Bool>.Binding? = nil) {
        self.searchTextWrapper = searchTextWrapper
        self.placeholder = placeholder
        self._isSearching = isSearching
        self.dismissButtonTitle = dismissButtonTitle
        self.dismissButtonCallback = dismissButtonCallback
        self.focused = focused
    }

    public var body: some View {
        GeometryReader { reader in
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "magnifyingglass")
                if let focused {
                    TextField(self.placeholder,
                              text: self.$searchTextWrapper.searchText)
                        .focused(focused)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                } else {
                    TextField(self.placeholder,
                              text: self.$searchTextWrapper.searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                if !self.searchTextWrapper.searchText.isEmpty {
                    Button(action: {
                        self.searchTextWrapper.searchText = ""
                        self.isSearching = false
                        self.dismissButtonCallback?()
                    }, label: {
                        Text(self.dismissButtonTitle).foregroundStyle(.pink)
                    })
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("searchField.cancelButton")
                    .animation(.easeInOut, value: self.searchTextWrapper.searchText.isEmpty)
                }
            }
            .onChange(of: self.searchTextWrapper.searchText) { _, newValue in
                self.isSearching = !newValue.isEmpty
            }
            .preference(key: OffsetTopPreferenceKey.self,
                        value: reader.frame(in: .global).minY)
            .padding(4)
        }.frame(height: 44)
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
#Preview {
    let withText = SearchTextObservable()
    withText.searchText = "Test"

    return VStack {
        SearchField(searchTextWrapper: SearchTextObservable(),
                    placeholder: "Search anything",
                    isSearching: .constant(false))
        SearchField(searchTextWrapper: withText,
                    placeholder: "Search anything",
                    isSearching: .constant(false))

        List {
            SearchField(searchTextWrapper: withText,
                        placeholder: "Search anything",
                        isSearching: .constant(false))
            Section(header: SearchField(searchTextWrapper: withText,
                                        placeholder: "Search anything",
                                        isSearching: .constant(false))) {
                SearchField(searchTextWrapper: withText,
                            placeholder: "Search anything",
                            isSearching: .constant(false))
            }
        }

        List {
            SearchField(searchTextWrapper: withText,
                        placeholder: "Search anything",
                        isSearching: .constant(false))
            Section(header: SearchField(searchTextWrapper: withText,
                                        placeholder: "Search anything",
                                        isSearching: .constant(false))) {
                SearchField(searchTextWrapper: withText,
                            placeholder: "Search anything",
                            isSearching: .constant(false))
            }
        }
        #if os(iOS) || os(tvOS)
        .listStyle(.grouped)
        #endif
    }
}
