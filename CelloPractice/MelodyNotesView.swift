import SwiftUI

/// The same proportional note tiles guide manual listening and a timed take.
struct MelodyNotesView: View {
    let context: MelodyPracticeContext
    let elapsed: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(context.section == .whole ? Array(0..<4) : [0], id: \.self) { phrase in
                phraseRow(phrase)
            }
        }
    }

    private func phraseRow(_ phrase: Int) -> some View {
        let events = context.expectedEvents.enumerated().filter { Int($0.element.onsetBeat / 4) == phrase }
        let current = elapsed.flatMap { context.eventIndex(at: $0) }
        return VStack(alignment: .leading, spacing: 6) {
            Text(context.section == .whole ? "Phrase \(phrase + 1)" : context.section.title)
                .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(events, id: \.offset) { index, event in
                        let note = context.frequency(for: event).map {
                            TunerReading(frequency: $0, targetFrequency: nil).noteName
                        } ?? "Rest"
                        Text(note).font(.system(size: 14, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7).lineLimit(1)
                            .frame(width: max(0, (geometry.size.width - CGFloat(max(0, events.count - 1)) * 4)
                                * event.durationBeats / 4), height: 40)
                            .foregroundStyle(current == index ? .white : Palette.forest)
                            .background(current == index ? Palette.forest : Palette.forest.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .accessibilityLabel("\(note), \(event.durationBeats.formatted()) beats")
                    }
                }
            }.frame(height: 40)
        }
    }
}
