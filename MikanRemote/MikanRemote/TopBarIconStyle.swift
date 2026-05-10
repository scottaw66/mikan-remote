import SwiftUI

private struct TopBarIconModifier: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(tint)
    }
}

extension View {
    func topBarIcon(tint: Color = .secondary) -> some View {
        modifier(TopBarIconModifier(tint: tint))
    }
}
