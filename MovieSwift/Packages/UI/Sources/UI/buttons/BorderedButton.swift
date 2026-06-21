import SwiftUI

public struct BorderedButton: View {
    public let text: String
    public let systemImageName: String
    public let color: Color
    public let isOn: Bool
    public let action: () -> Void

    #if os(macOS)
    @FocusState private var isFocused: Bool
    #endif

    public init(text: String, systemImageName: String, color: Color, isOn: Bool, action: @escaping () -> Void) {
        self.text = text
        self.systemImageName = systemImageName
        self.color = color
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: {
            self.action()
        }, label: {
            HStack(alignment: .center, spacing: 4) {
                // The symbol fills + bounces when `isOn` toggles. Callers that
                // pass a constant `isOn` (e.g. the filter / refill buttons)
                // never animate, which is the intended no-op.
                Image(systemName: systemImageName)
                    .symbolVariant(isOn ? .fill : .none)
                    .symbolEffect(.bounce, value: isOn)
                    .foregroundStyle(isOn ? .white : color)
                Text(text).foregroundStyle(isOn ? .white : color)
            }
            })
            .buttonStyle(.borderless)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: isOn ? 0 : 2)
                .background(isOn ? color : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8)))
            #if os(macOS)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? color.opacity(isOn ? 0.16 : 0.10) : .clear)
            )
            .shadow(color: isFocused ? color.opacity(0.20) : .clear,
                    radius: 10,
                    x: 0,
                    y: 0)
            .shadow(color: isFocused ? Color.black.opacity(0.12) : .clear,
                    radius: 4,
                    x: 0,
                    y: 3)
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isFocused)
            #endif
    }
}

#Preview {
    VStack {
        BorderedButton(text: "Add to wishlist",
                       systemImageName: "film",
                       color: .green,
                       isOn: false,
                       action: {

        })
        BorderedButton(text: "Add to wishlist",
                       systemImageName: "film",
                       color: .blue,
                       isOn: true,
                       action: {

        })
    }
}
