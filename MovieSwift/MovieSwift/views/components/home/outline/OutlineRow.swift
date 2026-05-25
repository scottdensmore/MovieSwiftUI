import SwiftUI

struct OutlineRow : View {
    let item: OutlineMenu
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Group {
                Image(systemName: item.image)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? Color.steam_gold : .primary)
            }
            .frame(width: 40)
            Text(item.title)
                .font(.FjallaOne(size: 24))
                .foregroundStyle(isSelected ? Color.steam_gold : .primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    OutlineRow(item: .popular, isSelected: true)
}
