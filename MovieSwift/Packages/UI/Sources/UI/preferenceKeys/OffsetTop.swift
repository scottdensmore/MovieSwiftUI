import SwiftUI

public struct OffsetTopPreferenceKey: PreferenceKey {
    static public let defaultValue: CGFloat = 0
    public typealias Value = CGFloat
    
    static public func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
