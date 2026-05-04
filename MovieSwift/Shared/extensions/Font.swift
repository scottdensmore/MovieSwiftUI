//
//  Font.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI

extension Font {
    /// Custom-font factories accept an optional `relativeTo:` so the
    /// resulting font scales with the user's Dynamic Type setting.
    /// Default to `.body` so existing call sites pick up scaling for
    /// free without an audit pass — section headers and large titles
    /// can still pass `.title` / `.largeTitle` for a more dramatic
    /// scaling curve.

    public static func FHACondFrenchNC(size: CGFloat,
                                       relativeTo style: Font.TextStyle = .body) -> Font {
        return Font.custom("FHA Condensed French NC", size: size, relativeTo: style)
    }

    public static func AmericanCaptain(size: CGFloat,
                                       relativeTo style: Font.TextStyle = .body) -> Font {
        return Font.custom("American Captain", size: size, relativeTo: style)
    }

    public static func FjallaOne(size: CGFloat,
                                 relativeTo style: Font.TextStyle = .body) -> Font {
        return Font.custom("FjallaOne-Regular", size: size, relativeTo: style)
    }
}

struct TitleFont: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        // .titleStyle() is used for section headings ("Popular
        // people", "Known for", "Fan level", etc.) — apply the
        // `.isHeader` accessibility trait so VoiceOver navigates
        // the page by heading. This pairs with the FjallaOne font
        // and 16pt title size that compose the visual heading look.
        return content
            .font(.FjallaOne(size: size, relativeTo: .title3))
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    func titleFont(size: CGFloat) -> some View {
        return ModifiedContent(content: self, modifier: TitleFont(size: size))
    }

    func titleStyle() -> some View {
        return ModifiedContent(content: self, modifier: TitleFont(size: 16))
    }
}
