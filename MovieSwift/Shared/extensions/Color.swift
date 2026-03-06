//
//  ColorScheme.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 13/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI

extension Color {
    public static var steam_white: Color {
        Color("steam_white", bundle: nil)
    }
    
    public static var steam_gold: Color {
        Color("steam_gold", bundle: nil)
    }
    
    public static var steam_rust: Color {
        Color("steam_rust", bundle: nil)
    }
    
    public static var steam_rust2: Color {
        Color("steam_rust2", bundle: nil)
    }
    
    public static var steam_bronze: Color {
        Color("steam_bronze", bundle: nil)
    }
    
    public static var steam_brown: Color {
        Color("steam_brown", bundle: nil)
    }
    
    public static var steam_yellow: Color {
        Color("steam_yellow", bundle: nil)
    }
    
    public static var steam_blue: Color {
        Color("steam_blue", bundle: nil)
    }
    
    public static var steam_bordeaux: Color {
        Color("steam_bordeaux", bundle: nil)
    }
    
    public static var steam_green: Color {
        Color("steam_green", bundle: nil)
    }
    
    public static var steam_background: Color {
        Color("steam_background", bundle: nil)
    }

    public static var steam_selection: Color {
        Color.steam_white.opacity(0.12)
    }
}

extension View {
    func softSelectionRow(_ isSelected: Bool,
                          cornerRadius: CGFloat = 10) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.steam_selection : .clear)
        )
    }
}

struct SoftSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .softSelectionRow(configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
