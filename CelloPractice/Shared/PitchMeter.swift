import SwiftUI

struct PitchMeter: View {
    let cents: Double
    let active: Bool
    var range: Double = 50
    /// On a white card the meter is drawn in the app's greens instead of white.
    var onCard = false
    var body: some View {
        let line = onCard ? Palette.forest : Color.white
        let near = onCard ? Palette.forest : Color(red: 0.80, green: 0.90, blue: 0.70)
        let far = onCard ? Palette.gold : Color(red: 0.98, green: 0.76, blue: 0.47)
        return GeometryReader { geometry in
            ZStack {
                Capsule().fill(line.opacity(0.12)).frame(height: 5)
                ForEach(-2...2, id: \.self) { tick in
                    Rectangle().fill(line.opacity(tick == 0 ? 0.9 : 0.25))
                        .frame(width: tick == 0 ? 2 : 1, height: tick == 0 ? 26 : 12)
                        .offset(x: CGFloat(tick) * geometry.size.width / 4)
                }
                if active {
                    Circle().fill(abs(cents) <= 10 ? near : far)
                        .frame(width: 15, height: 15)
                        .offset(x: CGFloat(min(range, max(-range, cents)) / (2 * range)) * geometry.size.width)
                        .animation(.linear(duration: 0.1), value: cents)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}
