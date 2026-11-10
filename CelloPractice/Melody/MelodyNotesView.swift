import SwiftUI

/// The same proportional note tiles guide manual listening and a timed take.
struct MelodyNotesView: View {
    enum LabelStyle { case pitch, rhythm }
    let context: MelodyPracticeContext
    let elapsed: TimeInterval?
    var labelStyle: LabelStyle = .pitch
    var focusOnCurrentPhrase = false
    @ScaledMetric(relativeTo: .footnote) private var tileHeight: CGFloat = 40

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
                    let rowWidth: CGFloat = geometry.size.width - CGFloat(max(0, events.count - 1)) * 4
                    ForEach(events, id: \.offset) { index, event in
                        tile(event, width: max(0, rowWidth * CGFloat(event.durationBeats) / 4),
                             isCurrent: current == index)
                    }
                }
            }.frame(height: tileHeight)
        }
    }

    // Kept as small typed steps: one long expression here exceeds the type-checker's
    // time limit on some Xcode versions.
    private func tile(_ event: MelodyEvent, width: CGFloat, isCurrent: Bool) -> some View {
        let beats: String = event.durationBeats.formatted()
        let note: String = context.frequency(for: event).map {
            TunerReading(frequency: $0, targetFrequency: nil).noteName
        } ?? "Rest"
        let label: String
        if labelStyle == .pitch || event.midiNote == nil { label = note }
        else if event.durationBeats == 0.5 { label = "½" }
        else if event.durationBeats == 1.5 { label = "1½" }
        else { label = beats }
        let spoken: String = labelStyle == .pitch ? "\(note), \(beats) beats"
            : "\(event.midiNote == nil ? "Rest" : "Note"), \(beats) beats"
        let foreground: Color = isCurrent ? .white : Palette.forest
        let background: Color = isCurrent ? Palette.forest : Palette.forest.opacity(0.07)
        return Text(label).font(.system(.footnote, design: .rounded).weight(.semibold))
            .minimumScaleFactor(0.7).lineLimit(1)
            .frame(width: width, height: tileHeight)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Layout.tileRadius))
            .accessibilityLabel(spoken)
    }
}
