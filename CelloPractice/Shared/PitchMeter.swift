import SwiftUI

/// Where the sound is against the note: the centre line is the note itself, and the band
/// around it, closed by two marks, is how far off still counts.
struct PitchMeter: View {
    let cents: Double
    let active: Bool
    var range: Double = 50
    /// How far from the note still counts, in cents.
    let tolerance: Double
    /// On a white card the meter is drawn in the app's greens instead of white.
    var onCard = false
    var body: some View {
        let line = onCard ? Palette.forest : Color.white
        let near = onCard ? Palette.forest : Color(red: 0.80, green: 0.90, blue: 0.70)
        let far = onCard ? Palette.gold : Color(red: 0.98, green: 0.76, blue: 0.47)
        return GeometryReader { geometry in
            let edge = CGFloat(min(1, tolerance / range)) * geometry.size.width / 2
            ZStack {
                Capsule().fill(line.opacity(0.12)).frame(height: 5)
                Capsule().fill(line.opacity(0.22)).frame(width: edge * 2, height: 12)
                ForEach([-1, 0, 1], id: \.self) { mark in
                    Rectangle().fill(line.opacity(mark == 0 ? 0.9 : 0.6))
                        .frame(width: 2, height: mark == 0 ? 26 : 18)
                        .offset(x: CGFloat(mark) * edge)
                }
                if active {
                    Circle().fill(abs(cents) <= tolerance ? near : far)
                        .frame(width: 15, height: 15)
                        .offset(x: CGFloat(min(range, max(-range, cents)) / (2 * range)) * geometry.size.width)
                        .animation(.linear(duration: 0.1), value: cents)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}
