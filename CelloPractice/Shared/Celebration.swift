import SwiftUI
import UIKit

private struct CelebratesResultsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True on practice screens, where a result has just been earned. A result
    /// opened later from Recordings shows its stars without ceremony.
    var celebratesResults: Bool {
        get { self[CelebratesResultsKey.self] }
        set { self[CelebratesResultsKey.self] = newValue }
    }
}

/// Celebrations are sized to the achievement: stars pop in for a three-star
/// take, and fireworks mark gold and a finished level.
enum Celebration {
    static let fireworksDuration = 2.4

    /// True when any lesson has more gold parts than before. Parts are counted
    /// so that each phrase or note's gold is marked, not only the last one.
    static func earnedGold(from old: [String: Int], to new: [String: Int]) -> Bool {
        new.contains { id, count in count > old[id, default: 0] }
    }
}

/// Three bursts of gold and green sparks over the whole screen. It is silent,
/// never blocks touches, and becomes a still badge when Reduce Motion is on.
struct FireworksView: View {
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        Group {
            if reduceMotion {
                badge.transition(.opacity)
            } else {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    ZStack {
                        Canvas { context, size in
                            for burst in Self.bursts { draw(burst, at: elapsed, in: &context, size: size) }
                        }
                        badge.opacity(min(1, elapsed * 3) * max(0, min(1, (Celebration.fireworksDuration - elapsed) * 3)))
                    }
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false)
            .accessibilityElement(children: .ignore).accessibilityLabel(title)
            .accessibilityIdentifier("fireworks")
            .onAppear {
                start = Date()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
    }

    private var badge: some View {
        Label(title, systemImage: "star.circle.fill").font(.headline).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Palette.gold, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 110)
    }

    private struct Burst {
        let x: Double
        let y: Double
        let delay: Double
        let color: Color
    }

    private static let bursts = [
        Burst(x: 0.28, y: 0.30, delay: 0, color: Palette.gold),
        Burst(x: 0.72, y: 0.24, delay: 0.35, color: Palette.forest),
        Burst(x: 0.50, y: 0.42, delay: 0.7, color: Palette.gold)
    ]

    /// Sparks fly out, slow down, sink a little and fade.
    private func draw(_ burst: Burst, at elapsed: Double, in context: inout GraphicsContext, size: CGSize) {
        let time = elapsed - burst.delay
        guard time > 0, time < 1.5 else { return }
        let progress = time / 1.5
        let reach = min(size.width, size.height) * 0.34 * (1 - pow(1 - progress, 3))
        let sparks = 22
        for spark in 0..<sparks {
            let angle = Double(spark) / Double(sparks) * 2 * .pi
            // Alternate lengths so the burst is not a perfect ring.
            let length = reach * (spark.isMultiple(of: 2) ? 1 : 0.62)
            let point = CGPoint(x: burst.x * size.width + cos(angle) * length,
                                y: burst.y * size.height + sin(angle) * length + progress * progress * 46)
            let radius = 4.5 * (1 - progress) + 1.2
            context.opacity = 1 - progress
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(burst.color))
        }
    }
}
