import Charts
import Foundation
import SwiftUI

/// The finished round's recorded taps. Missing beats never acquire zero offsets.
struct PulseTimingChartData {
    struct Point: Identifiable, Equatable {
        let beat: Int
        let position: Double
        let offsetSeconds: Double

        var id: Int { beat }
        var milliseconds: Double { offsetSeconds * 1_000 }
        // Use the same boundary and tolerance as the timing-star calculation.
        var isOnTime: Bool { abs(offsetSeconds) <= PulseAttempt.timingTolerance + 1e-9 }
    }

    let points: [Point]
    let missedBeats: [Int]
    let hasValidBeatCount: Bool
    let beatRange: ClosedRange<Double>
    let offsetRange: ClosedRange<Double>
    let exercise: RhythmExercise
    let positions: [Double]
    let unexpectedTapCount: Int

    init(totalBeats: Int, offsets: [Int: TimeInterval], exercise: RhythmExercise = .pulse,
         unexpectedTapCount: Int = 0) {
        self.exercise = exercise
        self.unexpectedTapCount = max(0, unexpectedTapCount)
        // Mixed rhythms leave deliberate spaces between some taps.
        let positions = exercise == .mixedRhythm ? exercise.tapTimes.map { $0 + 1 }
            : (1...exercise.tapCount).map(Double.init)
        self.positions = positions
        // An invalid round should not turn into an invented set of missed taps.
        hasValidBeatCount = totalBeats == exercise.tapCount
        beatRange = 0.5...((positions.last ?? 1) + 0.5)
        guard hasValidBeatCount else {
            points = []
            missedBeats = []
            offsetRange = -250...250
            return
        }

        points = offsets.compactMap { index, offset -> Point? in
            guard (0..<totalBeats).contains(index), offset.isFinite,
                  abs(offset) <= exercise.tapWindow + 1e-9 else { return nil }
            return Point(beat: index + 1, position: positions[index], offsetSeconds: offset)
        }.sorted { $0.beat < $1.beat }
        let tappedBeats = Set(points.map(\.beat))
        missedBeats = (1...totalBeats).filter { !tappedBeats.contains($0) }

        // Retain every valid tap, including those far outside the goal band.
        let furthest = points.map { abs($0.milliseconds) }.max() ?? 0
        let limit = max(250, ceil(furthest * 1.1 / 50) * 50)
        offsetRange = -limit...limit
    }

    var onTimeCount: Int { points.filter(\.isOnTime).count }
    var earlyCount: Int { points.filter { !$0.isOnTime && $0.offsetSeconds < 0 }.count }
    var lateCount: Int { points.filter { !$0.isOnTime && $0.offsetSeconds > 0 }.count }

    var accessibilitySummary: String {
        guard hasValidBeatCount else { return "Recorded timing data is unavailable for this round." }
        let extras = exercise == .mixedRhythm ? " \(unexpectedTapCount) extra taps outside the pattern." : ""
        return "Recorded timing chart. \(points.count) taps across \(exercise.wholeBeats) beats: \(onTimeCount) on time within 150 milliseconds, \(earlyCount) early, \(lateCount) late, \(missedBeats.count) missed.\(extras) Zero milliseconds is on the expected tap; negative values are early and positive values are late. Missed taps have no timing point."
    }
}

struct PulseTimingChartView: View {
    let attempt: PulseAttempt

    var body: some View {
        let data = PulseTimingChartData(totalBeats: attempt.totalBeats, offsets: attempt.offsets,
                                       exercise: attempt.exercise, unexpectedTapCount: attempt.unexpectedTapCount)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your timing").font(.headline).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.forest.opacity(0.16))
                        .frame(width: 12, height: 9)
                    Text("±150 ms").font(.caption).foregroundStyle(Palette.muted)
                }.accessibilityLabel("Goal band, plus or minus 150 milliseconds")
            }

            if data.hasValidBeatCount {
                Chart {
                    RectangleMark(
                        xStart: .value("Start", data.beatRange.lowerBound),
                        xEnd: .value("End", data.beatRange.upperBound),
                        yStart: .value("Early goal", -PulseAttempt.timingTolerance * 1_000),
                        yEnd: .value("Late goal", PulseAttempt.timingTolerance * 1_000)
                    ).foregroundStyle(Palette.forest.opacity(0.10))

                    RuleMark(y: .value("On beat", 0))
                        .foregroundStyle(Palette.forest.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("On beat 0").font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Palette.forest)
                        }

                    ForEach(data.points) { point in
                        PointMark(x: .value("Tap position", point.position), y: .value("Timing", point.milliseconds))
                            .symbolSize(22)
                            .foregroundStyle(point.isOnTime ? Palette.forest : Palette.gold)
                    }
                }
                .chartXScale(domain: data.beatRange)
                .chartYScale(domain: data.offsetRange)
                .chartXAxis {
                    AxisMarks(values: data.positions) { value in
                        AxisTick().foregroundStyle(Palette.muted.opacity(0.35))
                        AxisValueLabel(centered: false, anchor: .top,
                                       collisionResolution: .disabled, horizontalSpacing: 0) {
                            if let value = value.as(Double.self), let index = data.positions.firstIndex(of: value) {
                                let beat = index + 1
                                VStack(spacing: 3) {
                                    Text(attempt.exercise.beatLabel(forTap: beat)).font(.system(size: 9).monospacedDigit())
                                    Image(systemName: "xmark")
                                        .font(.system(size: 6, weight: .semibold))
                                        .opacity(data.missedBeats.contains(beat) ? 1 : 0)
                                }.foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Palette.muted.opacity(0.10))
                        AxisValueLabel {
                            if let offset = value.as(Double.self) {
                                Text(offset > 0 ? "+\(Int(offset))" : "\(Int(offset))")
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(data.accessibilitySummary)
                .accessibilityHint("Crosses under beat numbers mark missed taps.")
                .accessibilityIdentifier("pulseTimingChart")

                HStack {
                    Text("− early · + late")
                    Spacer(minLength: 5)
                    if !data.missedBeats.isEmpty {
                        Label("\(data.missedBeats.count) missed", systemImage: "xmark")
                    }
                }.font(.caption2).foregroundStyle(Palette.muted)
                if attempt.exercise == .mixedRhythm && data.unexpectedTapCount > 0 {
                    Text("\(data.unexpectedTapCount) extra taps outside the pattern")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            } else {
                Text("No timing data to plot for this round.")
                    .font(.subheadline).foregroundStyle(Palette.muted).padding(.vertical, 14)
            }
        }.card()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pulseTimingChartCard")
    }
}
