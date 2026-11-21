import CelloPitch
import Charts
import Foundation
import SwiftUI

/// A picture of the saved tuner observations, not the audio-derived star score.
/// Points stay discrete so an absent detection never becomes a drawn note.
struct PitchTraceData {
    struct Point: Identifiable, Equatable {
        let id: Int
        let time: Double
        let cents: Double
        var isNearTarget: Bool { abs(cents) <= 25 + 1e-8 }
    }

    let points: [Point]
    let timeRange: ClosedRange<Double>
    let centsRange: ClosedRange<Double>
    let hasValidTarget: Bool

    init(samples: [PitchSample], targetFrequency: Double, duration: Double) {
        let validTarget = targetFrequency.isFinite && targetFrequency > 0
        hasValidTarget = validTarget
        let validDuration = duration.isFinite && duration >= 0 ? duration : nil
        points = samples.enumerated().compactMap { index, sample -> Point? in
            guard validTarget, sample.time.isFinite, sample.time >= 0,
                  validDuration.map({ sample.time <= $0 }) ?? true,
                  sample.frequency.isFinite, sample.frequency > 0,
                  sample.confidence.isFinite, (0.75...1).contains(sample.confidence),
                  sample.rms.isFinite, sample.rms > 0 else { return nil }
            let cents = Measure.cents(sample.frequency, from: targetFrequency)
            guard cents.isFinite else { return nil }
            return Point(id: index, time: sample.time, cents: cents)
        }.sorted {
            if $0.time != $1.time { return $0.time < $1.time }
            return $0.id < $1.id
        }
        timeRange = 0...max(validDuration ?? points.last?.time ?? 0, 1)
        // Keep every accepted observation visible, including octave errors. A
        // fixed display limit would make a distant note appear near the target.
        let furthest = points.map { abs($0.cents) }.max() ?? 0
        let limit = max(50, ceil(furthest * 1.1 / 25) * 25)
        centsRange = -limit...limit
    }

    var nearTargetCount: Int { points.filter(\.isNearTarget).count }

    /// Where the take mostly sat, in plain words, with what to do about it.
    var tip: String? {
        guard !points.isEmpty else { return nil }
        let sorted = points.map(\.cents).sorted()
        let middle = sorted[sorted.count / 2]
        let amount = Int(abs(middle).rounded())
        if abs(middle) <= 25 { return "Mostly on the note. Keep it there for the whole take." }
        return middle > 0 ? "Mostly \(amount)¢ sharp. Let the pitch settle a little lower."
            : "Mostly \(amount)¢ flat. Lift the pitch a little."
    }
    var aboveTargetCount: Int { points.filter { $0.cents > 25 + 1e-8 }.count }
    var belowTargetCount: Int { points.filter { $0.cents < -25 - 1e-8 }.count }

    var accessibilitySummary: String {
        guard hasValidTarget else { return "A target note is needed to show the pitch chart." }
        guard !points.isEmpty else { return "No clear recorded pitch observations to plot." }
        return "Recorded pitch chart. \(points.count) observations: \(nearTargetCount) within 25 cents of the target, \(aboveTargetCount) above the goal band and \(belowTargetCount) below. Gaps have no detected pitch. These observations are separate from the audio-derived star score."
    }
}

struct PitchTraceView: View {
    let samples: [PitchSample]
    let targetFrequency: Double
    let duration: Double

    private var data: PitchTraceData {
        PitchTraceData(samples: samples, targetFrequency: targetFrequency, duration: duration)
    }

    var body: some View {
        let trace = data
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your pitch").font(.headline).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.forest.opacity(0.16))
                        .frame(width: 12, height: 9)
                    Text("±25¢").font(.caption).foregroundStyle(Palette.muted)
                }
                .accessibilityLabel("Goal band, plus or minus 25 cents")
            }

            if !trace.hasValidTarget {
                Text("Choose a target note to see your pitch.")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(.vertical, 14)
            } else if trace.points.isEmpty {
                Text("No clear pitch to plot for this take.")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(.vertical, 14)
            } else {
                Chart {
                    RectangleMark(
                        xStart: .value("Start", trace.timeRange.lowerBound),
                        xEnd: .value("End", trace.timeRange.upperBound),
                        yStart: .value("Lower goal", -25),
                        yEnd: .value("Upper goal", 25)
                    ).foregroundStyle(Palette.forest.opacity(0.10))

                    RuleMark(y: .value("Target", 0))
                        .foregroundStyle(Palette.forest.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    ForEach(trace.points) { point in
                        PointMark(x: .value("Time", point.time), y: .value("Pitch", point.cents))
                            .symbolSize(15)
                            .foregroundStyle(point.isNearTarget ? Palette.forest : Palette.gold)
                    }
                }
                .chartXScale(domain: trace.timeRange)
                .chartYScale(domain: trace.centsRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                        AxisTick().foregroundStyle(Palette.muted.opacity(0.35))
                        AxisValueLabel {
                            if let time = value.as(Double.self) {
                                Text("\(time, format: .number.precision(.fractionLength(0...1)))s")
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    // Higher than the target is sharp, lower is flat: said in words, not in cents.
                    AxisMarks(position: .leading, values: [trace.centsRange.lowerBound * 0.6, 0, trace.centsRange.upperBound * 0.6]) { value in
                        AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                        AxisValueLabel {
                            if let cents = value.as(Double.self) {
                                Text(cents > 0 ? "Sharp" : cents < 0 ? "Flat" : NoteName.frequency(targetFrequency))
                                    .foregroundStyle(cents == 0 ? Palette.forest : Palette.muted)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trace.accessibilitySummary)
                .accessibilityHint("Above zero is higher pitch; below zero is lower pitch.")
                .accessibilityIdentifier("pitchTraceChart")
                if let tip = trace.tip {
                    Text(tip).font(.subheadline).foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("pitchTraceTip")
                }
            }
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier("pitchTraceCard")
    }
}
