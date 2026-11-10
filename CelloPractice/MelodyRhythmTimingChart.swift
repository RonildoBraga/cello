import Charts
import Foundation
import SwiftUI

/// Plot actual timing offsets at the score's note starts. A continuing note is
/// neither another expected tap nor a missing tap, and has no invented point.
struct MelodyRhythmChartData {
    struct Point: Identifiable, Equatable {
        let noteIndex: Int
        let time: Double
        let offsetSeconds: Double

        var id: Int { noteIndex }
        var milliseconds: Double { offsetSeconds * 1_000 }
        var isOnTime: Bool { abs(offsetSeconds) <= MelodyRhythmAttempt.timingTolerance + 1e-9 }
    }

    let hasValidContext: Bool
    let expectedTimes: [TimeInterval]
    let points: [Point]
    let missedNoteIndices: [Int]
    let timeRange: ClosedRange<Double>
    let offsetRange: ClosedRange<Double>
    let unexpectedTapCount: Int

    init(context: MelodyRhythmContext, offsets: [Int: TimeInterval], unexpectedTapCount: Int = 0) {
        let valid = context.isValid && unexpectedTapCount >= 0
        hasValidContext = valid
        self.unexpectedTapCount = valid ? unexpectedTapCount : 0
        expectedTimes = valid ? context.expectedTapTimes : []
        timeRange = 0...max(valid ? context.duration : 1, 0.1)
        guard valid else {
            points = []
            missedNoteIndices = []
            offsetRange = -250...250
            return
        }
        let times = expectedTimes
        points = offsets.compactMap { index, offset -> Point? in
            guard times.indices.contains(index), offset.isFinite,
                  abs(offset) <= context.tapWindow(for: index) + 1e-9,
                  times[index] + offset >= 0, times[index] + offset < context.duration else { return nil }
            return Point(noteIndex: index, time: times[index], offsetSeconds: offset)
        }.sorted { $0.noteIndex < $1.noteIndex }
        let matched = Set(points.map(\.noteIndex))
        missedNoteIndices = times.indices.filter { !matched.contains($0) }
        let furthest = points.map { abs($0.milliseconds) }.max() ?? 0
        let limit = max(250, ceil(furthest * 1.1 / 50) * 50)
        offsetRange = -limit...limit
    }

    var onTimeCount: Int { points.filter(\.isOnTime).count }
    var earlyCount: Int { points.filter { !$0.isOnTime && $0.offsetSeconds < 0 }.count }
    var lateCount: Int { points.filter { !$0.isOnTime && $0.offsetSeconds > 0 }.count }

    var accessibilitySummary: String {
        guard hasValidContext else { return "Recorded rhythm timing is unavailable for this round." }
        return "Recorded phrase timing chart. \(points.count) matched taps: \(onTimeCount) on time within 150 milliseconds, \(earlyCount) early, \(lateCount) late, \(missedNoteIndices.count) missed note starts, \(unexpectedTapCount) extra taps. The full \(timeRange.upperBound.formatted()) second phrase includes continuing notes. Negative offsets are early and positive offsets are late. Missing and extra taps have no invented timing offset."
    }
}

struct MelodyRhythmTimingChart: View {
    let attempt: MelodyRhythmAttempt

    var body: some View {
        let data = MelodyRhythmChartData(context: attempt.context, offsets: attempt.offsets,
                                         unexpectedTapCount: attempt.unexpectedTapCount)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your timing").font(.headline).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text("±150 ms").font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityLabel("Goal band, plus or minus 150 milliseconds")
            }
            if data.hasValidContext {
                Chart {
                    RectangleMark(xStart: .value("Start", data.timeRange.lowerBound),
                                  xEnd: .value("End", data.timeRange.upperBound),
                                  yStart: .value("Early goal", -MelodyRhythmAttempt.timingTolerance * 1_000),
                                  yEnd: .value("Late goal", MelodyRhythmAttempt.timingTolerance * 1_000))
                        .foregroundStyle(Palette.forest.opacity(0.10))
                    RuleMark(y: .value("Expected start", 0))
                        .foregroundStyle(Palette.forest.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    ForEach(data.points) { point in
                        PointMark(x: .value("Note start", point.time), y: .value("Timing", point.milliseconds))
                            .symbolSize(24).foregroundStyle(point.isOnTime ? Palette.forest : Palette.gold)
                    }
                    ForEach(data.missedNoteIndices, id: \.self) { index in
                        RuleMark(x: .value("Missed note start", data.expectedTimes[index]))
                            .foregroundStyle(Palette.muted.opacity(0.12))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                            .annotation(position: .bottom, spacing: 4) {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .semibold))
                                    .foregroundStyle(Palette.muted)
                            }
                    }
                }.chartXScale(domain: data.timeRange, range: .plotDimension(padding: 8))
                    .chartYScale(domain: data.offsetRange)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                            AxisValueLabel {
                                if let milliseconds = value.as(Double.self) {
                                    Text(milliseconds > 0 ? "+\(Int(milliseconds))" : "\(Int(milliseconds))")
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }.frame(height: 190)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(data.accessibilitySummary)
                    .accessibilityIdentifier("melodyRhythmTimingChart")
                HStack {
                    Text("− early · + late")
                    Spacer(minLength: 6)
                    Text("\(data.missedNoteIndices.count) missed · \(data.unexpectedTapCount) extra")
                }.font(.caption2).foregroundStyle(Palette.muted)
            } else {
                Text("No timing data to plot for this round.")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(.vertical, 14)
            }
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .accessibilityElement(children: .contain)
    }
}
