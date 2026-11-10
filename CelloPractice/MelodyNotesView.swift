import SwiftUI

/// The same proportional note tiles guide manual listening and a timed take.
struct MelodyNotesView: View {
    enum LabelStyle { case pitch, rhythm }
    let context: MelodyPracticeContext
    let elapsed: TimeInterval?
    var labelStyle: LabelStyle = .pitch
    var focusOnCurrentPhrase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(visiblePhrases, id: \.self) { phrase in
                phraseRow(phrase)
            }
        }
    }

    private var visiblePhrases: [Int] {
        guard context.section == .whole else { return [0] }
        guard focusOnCurrentPhrase else { return Array(0..<4) }
        let beat = max(0, elapsed ?? 0) * Double(context.tempoBPM) / 60
        return [min(3, Int(beat / 4))]
    }

    private func phraseRow(_ phrase: Int) -> some View {
        let events = context.expectedEvents.enumerated().filter { Int($0.element.onsetBeat / 4) == phrase }
        let current = elapsed.flatMap { context.eventIndex(at: $0) }
        return VStack(alignment: .leading, spacing: 6) {
            if context.section == .whole {
                Text("Phrase \(phrase + 1)").font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            }
            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(events, id: \.offset) { index, event in
                        let note = context.frequency(for: event).map {
                            TunerReading(frequency: $0, targetFrequency: nil).noteName
                        } ?? "Rest"
                        let label = labelStyle == .pitch || event.midiNote == nil ? note
                            : event.durationBeats == 0.5 ? "½"
                            : event.durationBeats == 1.5 ? "1½" : "\(event.durationBeats.formatted())"
                        Text(label).font(.system(size: 14, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7).lineLimit(1)
                            .frame(width: max(0, (geometry.size.width - CGFloat(max(0, events.count - 1)) * 4)
                                * event.durationBeats / 4), height: 40)
                            .foregroundStyle(current == index ? .white : Palette.forest)
                            .background(current == index ? Palette.forest : Palette.forest.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .accessibilityLabel(labelStyle == .pitch ? "\(note), \(event.durationBeats.formatted()) beats"
                                                : "\(event.midiNote == nil ? "Rest" : "Note"), \(event.durationBeats.formatted()) beats")
                    }
                }
            }.frame(height: 40)
        }
    }
}
