import SwiftUI

public struct RoundedBadge : View {
    public let text: String
    public let color: Color
    
    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        HStack {
            Text(text.capitalized)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.leading, 10)
                .padding([.top, .bottom], 5)
            Image(systemName: "chevron.right")
                .resizable()
                .frame(width: 5, height: 10)
                .foregroundStyle(.primary)
                .padding(.trailing, 10)
            
            }
            .background(
                Rectangle()
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
        )
            .padding(.bottom, 4)
    }
}

#Preview {
    RoundedBadge(text: "Test", color: .blue)
}
