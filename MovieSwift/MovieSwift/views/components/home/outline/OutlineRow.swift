//
//  OutlineRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 27/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI

struct OutlineRow : View {
    let item: OutlineMenu
    @Binding var selectedMenu: OutlineMenu
    
    var isSelected: Bool {
        selectedMenu == item
    }
    
    var body: some View {
        HStack {
            Group {
                Image(systemName: item.image)
                    .imageScale(.large)
                    .foregroundColor(isSelected ? .steam_gold : .primary)
            }
            .frame(width: 40)
            Text(item.title)
                .font(.FjallaOne(size: 24))
                .foregroundColor(isSelected ? .steam_gold : .primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(isSelected ? Color.secondary.opacity(0.1) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            self.selectedMenu = self.item
        }
    }
}

#if DEBUG
struct OutlineRow_Previews : PreviewProvider {
    static var previews: some View {
        OutlineRow(item: .popular, selectedMenu: .constant(.popular))
    }
}
#endif
