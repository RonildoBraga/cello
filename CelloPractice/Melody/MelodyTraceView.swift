import Charts
import Foundation
import SwiftUI

/// Saved pitch stays in its original octave. Missing or uncertain readings break
/// the trace rather than drawing a line across a pause or inventing a note.
struct MelodyTraceData {
    struct ExpectedNote: Identifiable, Equatable {
        let id: Int
        let start: Double
        let end: Double
        let pitch: Double
    }

    struct Point: Identifiable, Equatable {
        let id: Int
        let time: Double
        let pitch: Double
        let segment: Int
    }

    private struct Observation {
        let time: Double
        let frequency: Double?
        let confidence: Double
        let rms: Double
        let ambiguous: Bool
    }

    let expectedNotes: [ExpectedNote]
    let points: [Point]
    let timeRange: ClosedRange<Double>
    let pitchRange: ClosedRange<Double>
    let pitchTicks: [Double]
    let hasValidContext: Bool

    init(context: MelodyPracticeContext, samples: [PitchSample], duration: Double) {
        self.init(context: context, observations: samples.map {
            Observation(time: $0.time, frequency: $0.frequency, confidence: $0.confidence,
                        rms: $0.rms, ambiguous: false)
        }, duration: duration)
    }

    init(context: MelodyPracticeContext, rating: MelodyRating, duration: Double) {
        self.init(context: context, observations: rating.pitchPoints.map {
            Observation(time: $0.time, frequency: $0.frequency, confidence: $0.confidence,
                        rms: $0.rms, ambiguous: $0.ambiguous)
        }, duration: duration)
    }

    private init(context: MelodyPracticeContext, observations: [Observation], duration: Double) {
        hasValidContext = context.isValid
        let referenceDuration = context.isValid ? context.duration : 0
        let savedDuration = duration.isFinite && (0...192).contains(duration) ? duration : referenceDuration
        let end = max(1, max(referenceDuration, savedDuration))
        timeRange = 0...end
        let tuning = context.isValid ? context.tuningA4Hz : 440
        func pitch(_ frequency: Double) -> Double {
            69 + 12 * (log2(frequency) - log2(tuning))
        }
        expectedNotes = context.isValid ? context.expectedEvents.enumerated().compactMap { index, event in
            guard let note = event.midiNote else { return nil }
            return ExpectedNote(id: index, start: event.onsetBeat * 60 / Double(context.tempoBPM),
                                end: event.endBeat * 60 / Double(context.tempoBPM), pitch: Double(note))
        } : []

        let timed = observations.enumerated().filter {
            $0.element.time.isFinite && (0...savedDuration).contains($0.element.time)
        }.sorted {
            $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time
        }
        var plotted: [Point] = []
        var previousTime: Double?
        var segment = -1
        if context.isValid {
            for (index, observation) in timed {
                guard let frequency = observation.frequency, frequency.isFinite,
                      (20...20_000).contains(frequency),
                      observation.confidence.isFinite, (0.75...1).contains(observation.confidence),
                      observation.rms.isFinite, observation.rms >= 0.0008,
                      !observation.ambiguous else {
                    previousTime = nil
                    continue
                }
                if previousTime.map({ observation.time <= $0 || observation.time - $0 > 0.25 + 1e-8 }) ?? true {
                    segment += 1
                }
                plotted.append(Point(id: index, time: observation.time, pitch: pitch(frequency), segment: segment))
                previousTime = observation.time
            }
        }
        points = plotted
        let pitches = expectedNotes.map(\.pitch) + plotted.map(\.pitch)
        let low = floor(pitches.min() ?? 48) - 1
        let high = ceil(pitches.max() ?? 52) + 1
        pitchRange = low...max(low + 2, high)
        if high - low <= 8, !expectedNotes.isEmpty {
            pitchTicks = Array(Set(expectedNotes.map { $0.pitch.rounded() })).sorted()
        } else {
            pitchTicks = Array(Set([low + 1, ((low + high) / 2).rounded(), high - 1])).sorted()
        }
    }

    static func noteName(for pitch: Double) -> String {
        guard pitch.isFinite, (-1_000...1_000).contains(pitch) else { return "—" }
        let midi = Int(pitch.rounded())
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(Int(floor(Double(midi) / 12)) - 1)"
    }

    var accessibilitySummary: String {
        guard hasValidContext else { return "The melody reference is unavailable." }
        guard !points.isEmpty else { return "Reference phrase chart. No clear saved pitch observations to plot." }
        return "Reference phrase and \(points.count) clear saved pitch observations. Higher points mean higher notes. Gaps have no clear pitch; the chart keeps the recorded octave. Stars use the saved audio assessment."
    }
}

struct MelodyTraceView: View {
    private let data: MelodyTraceData

    init(context: MelodyPracticeContext, samples: [PitchSample], duration: Double) {
        data = MelodyTraceData(context: context, samples: samples, duration: duration)
    }

    init(context: MelodyPracticeContext, rating: MelodyRating, duration: Double) {
        data = MelodyTraceData(context: context, rating: rating, duration: duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your phrase").font(.headline).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    legend("Reference", color: Palette.forest, dashed: true)
                    legend("Your hum", color: Palette.gold)
                }
            }
            if data.hasValidContext {
                Chart {
                    ForEach(data.expectedNotes) { note in
                        RuleMark(xStart: .value("Start", note.start), xEnd: .value("End", note.end),
                                 y: .value("Reference", note.pitch))
                            .foregroundStyle(Palette.forest.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                    ForEach(Array(zip(data.expectedNotes, data.expectedNotes.dropFirst())), id: \.1.id) { previous, next in
                        if abs(previous.end - next.start) < 1e-8, previous.pitch != next.pitch {
                            RuleMark(x: .value("Transition", next.start),
                                     yStart: .value("From", previous.pitch), yEnd: .value("To", next.pitch))
                                .foregroundStyle(Palette.forest.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    ForEach(data.points) { point in
                        LineMark(x: .value("Time", point.time), y: .value("Pitch", point.pitch),
                                 series: .value("Segment", point.segment))
                            .foregroundStyle(Palette.gold).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Time", point.time), y: .value("Pitch", point.pitch))
                            .foregroundStyle(Palette.gold).symbolSize(8)
                    }
                }
                .chartXScale(domain: data.timeRange)
                .chartYScale(domain: data.pitchRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                        AxisValueLabel {
                            if let time = value.as(Double.self) {
                                Text("\(time, format: .number.precision(.fractionLength(0...1)))s")
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: data.pitchTicks) { value in
                        AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                        AxisValueLabel {
                            if let pitch = value.as(Double.self) {
                                Text(MelodyTraceData.noteName(for: pitch)).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(data.accessibilitySummary)
                .accessibilityIdentifier("melodyPitchChart")
                if data.points.isEmpty {
                    Text("No clear pitch to plot for this take.").font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                Text("The melody reference is unavailable.").font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }

    private func legend(_ title: String, color: Color, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: dashed ? 5 : 12, height: 2)
            if dashed { Rectangle().fill(color).frame(width: 5, height: 2) }
            Text(title).font(.caption2).foregroundStyle(Palette.muted)
        }.accessibilityElement(children: .ignore).accessibilityLabel(title)
    }
}
