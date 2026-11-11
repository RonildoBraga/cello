import SwiftUI

/// One thing to do on the lane: a tap (no length) or a note to hold.
struct LaneMark: Equatable {
    /// Seconds from the first beat.
    let start: TimeInterval
    /// How long to hold; zero for a tap.
    var length: TimeInterval = 0
    var label: String? = nil
    /// Height on the lane from 0 (low) to 1 (high), so a higher note sits higher.
    var level: Double = 0.5
    /// A tap that was met; nil while it is still to come or was missed.
    var hit = false
}

/// What is coming, travelling towards a fixed line: taps as dots, notes as bars
/// whose length is how long to hold them and whose gaps are the pauses. The
/// count-in travels the same lane as 1 2 3 4, so the first tap or note can be
/// met on time instead of reacted to.
struct BeatLane: View {
    /// Seconds from the first beat; negative during the count-in.
    let elapsed: TimeInterval
    let beatInterval: TimeInterval
    var countInBeats = 4
    /// How long the take or round lasts after the count-in.
    let duration: TimeInterval
    let marks: [LaneMark]

    var body: some View {
        Canvas { context, size in
            let lineX = size.width * 0.2
            let pointsPerSecond = (size.width - lineX) / 3.2
            func x(_ time: TimeInterval) -> CGFloat { lineX + (time - elapsed) * pointsPerSecond }
            let top: CGFloat = 10
            let bottom = size.height - 26
            func y(_ level: Double) -> CGFloat { bottom - (bottom - top) * level }

            // Beats: the count-in as 1 2 3 4, then a faint tick on every beat.
            for beat in -countInBeats..<Int((duration / beatInterval).rounded(.up)) {
                let position = x(Double(beat) * beatInterval)
                guard position > -20, position < size.width + 20 else { continue }
                var tick = Path()
                tick.move(to: CGPoint(x: position, y: top - 6))
                tick.addLine(to: CGPoint(x: position, y: bottom + 6))
                context.stroke(tick, with: .color(.white.opacity(0.22)), lineWidth: 1)
                if beat < 0 {
                    context.draw(Text("\(beat + countInBeats + 1)").font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75)),
                                 at: CGPoint(x: position, y: size.height - 8))
                }
            }

            for mark in marks {
                let left = x(mark.start)
                let right = x(mark.start + mark.length)
                guard right > -12, left < size.width + 12 else { continue }
                let passed = right < lineX - 14
                if mark.length > 0 {
                    // A note: sounding while the line is inside its bar.
                    let bar = Path(roundedRect: CGRect(x: left, y: y(mark.level) - 9, width: max(6, right - left), height: 18),
                                   cornerRadius: 9)
                    let sounding = left <= lineX && right >= lineX
                    context.fill(bar, with: .color(sounding ? Palette.gold : .white.opacity(passed ? 0.25 : 0.9)))
                    if let label = mark.label, right - left > 26 {
                        context.draw(Text(label).font(.caption2.weight(.semibold))
                                        .foregroundStyle(sounding ? .white : Palette.forest.opacity(passed ? 0.5 : 1)),
                                     at: CGPoint(x: left + 16, y: y(mark.level)))
                    }
                } else {
                    // A tap: solid while coming, gold once hit, hollow once missed.
                    let dot = Path(ellipseIn: CGRect(x: left - 8, y: y(mark.level) - 8, width: 16, height: 16))
                    if mark.hit { context.fill(dot, with: .color(Palette.gold)) }
                    else if passed { context.stroke(dot, with: .color(.white.opacity(0.3)), lineWidth: 1.5) }
                    else { context.fill(dot, with: .color(.white)) }
                }
            }

            var line = Path()
            line.move(to: CGPoint(x: lineX, y: 0))
            line.addLine(to: CGPoint(x: lineX, y: size.height - 16))
            context.stroke(line, with: .color(.white), lineWidth: 2.5)
        }.accessibilityHidden(true)
    }
}
