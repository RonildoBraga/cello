import CelloPitch
import Foundation

/// Compares independently measured sound with a frozen score on the recording's
/// original timeline. It never transposes a hum or shifts it onto the target.
enum MelodyRecordingRater {
    static func rate(url: URL, context: MelodyPracticeContext) async -> MelodyRating {
        do {
            let samples = try await RecordingAudio.read(url: url, maximumDuration: min(26, context.duration + 2))
            return await Task.detached(priority: .userInitiated) {
                rate(samples: samples, sampleRate: 48_000, context: context)
            }.value
        } catch { return MelodyRating(status: .unclear) }
    }

    static func rate(samples: [Float], sampleRate: Double, context: MelodyPracticeContext) -> MelodyRating {
        guard context.isValid, context.gradingVersion == MelodyRating.currentVersion,
              context.duration <= 24, context.expectedEvents.contains(where: { $0.midiNote != nil }),
              sampleRate.isFinite, (8_000...96_000).contains(sampleRate),
              !samples.isEmpty, Double(samples.count) / sampleRate <= min(26, context.duration + 2),
              samples.allSatisfy(\.isFinite) else { return MelodyRating(status: .unclear) }
        let clipped = Double(samples.filter { abs($0) >= 0.999 }.count) / Double(samples.count)
        guard clipped < 0.001 else { return MelodyRating(status: .unclear) }
        // Automatic movie stop can include a short audio tail. Grade exactly the
        // frozen exercise interval while the original movie and live samples stay
        // available for review. This never moves the learner's onset in time.
        let count = min(samples.count, Int((context.duration * sampleRate).rounded(.down)))
        return analyse(samples: Array(samples.prefix(count)), sampleRate: sampleRate, context: context)
    }

    /// How far from a note a sound may be and still count as that note. The tuner and
    /// the chart draw this same band, so what is shown is what is scored.
    static let matchCents = 70.0
    /// A note shorter than this is a quick one. Starting a note afresh costs about a tenth
    /// of a second whatever its length, so a quick note has less sound left to be judged on.
    static let quickNote = 0.75

    private static func analyse(samples: [Float], sampleRate: Double, context: MelodyPracticeContext) -> MelodyRating {
        let window = max(512, Int(sampleRate * (8_192.0 / 48_000)))
        guard samples.count >= window else { return MelodyRating(status: .insufficientSound) }

        let cellSize = max(1, Int(sampleRate * 0.01))
        let levels: [Double] = stride(from: 0, to: samples.count, by: cellSize).map { start in
            let cell = samples[start..<min(start + cellSize, samples.count)]
            let mean = cell.reduce(0.0) { $0 + Double($1) } / Double(cell.count)
            return sqrt(cell.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(cell.count))
        }
        let floor = max(0.0008, min(0.01, (levels.max() ?? 0) * 0.08))
        let hop = max(1, Int(sampleRate * 0.05))
        var starts = Array(stride(from: 0, through: samples.count - window, by: hop))
        if starts.last != samples.count - window { starts.append(samples.count - window) }
        let detector = PitchDetector()
        let frames = starts.map { start -> Frame in
            let sound = Array(samples[start..<(start + window)])
            let estimate = detector.estimate(samples: sound, sampleRate: sampleRate)
            let accepted = estimate.flatMap { $0.confidence >= 0.80 ? $0 : nil }
            return Frame(time: Double(start + window / 2) / sampleRate, estimate: accepted,
                         ambiguous: accepted.map {
                RecordingAudio.octaveIsAmbiguous(sound, sampleRate: sampleRate, frequency: $0.frequency)
            } ?? false)
        }
        let slips = octaveSlips(in: frames.map { $0.estimate?.frequency })
        var frameIndex = 0
        let cells: [Cell] = levels.enumerated().map { index, rms in
            let time = (Double(index * cellSize) + Double(cellSize) / 2) / sampleRate
            while frameIndex + 1 < frames.count,
                  abs(frames[frameIndex + 1].time - time) < abs(frames[frameIndex].time - time) { frameIndex += 1 }
            let frame = frames[frameIndex]
            let active = rms >= floor
            let estimate = active && abs(frame.time - time) <= Double(window) / sampleRate / 2 + 0.001
                ? frame.estimate : nil
            return Cell(time: time, active: active, frequency: estimate?.frequency,
                        confidence: estimate?.confidence ?? 0, rms: rms,
                        ambiguous: estimate != nil && (frame.ambiguous || slips.contains(frameIndex)))
        }
        let cellDuration = Double(cellSize) / sampleRate
        let activeDuration = Double(cells.filter(\.active).count) * cellDuration
        let voiced = cells.filter { $0.frequency != nil }
        let voicedDuration = Double(voiced.count) * cellDuration
        let ambiguousFraction = voiced.isEmpty ? 0 : Double(voiced.filter(\.ambiguous).count) / Double(voiced.count)
        let points = cells.enumerated().compactMap { index, cell in
            index.isMultiple(of: 5) ? MelodyPitchPoint(time: cell.time, frequency: cell.frequency,
                confidence: cell.confidence, rms: cell.rms, ambiguous: cell.ambiguous) : nil
        }

        // Boundaries are inferred without the score: amplitude reattacks and
        // sustained pitch changes. One sustained note cannot stand in for eight taps.
        let secondsPerBeat = 60 / Double(context.tempoBPM)
        let boundaries = observedBoundaries(cells: cells, attackWindowDuration: Double(window) / sampleRate,
            noteStarts: context.expectedEvents.filter { $0.midiNote != nil }.map {
                (time: $0.onsetBeat * secondsPerBeat, slack: startSlack(noteDuration: $0.durationBeats * secondsPerBeat))
            })
        // What was heard, note by note, and which asked note each one was.
        let finish = Double(samples.count) / sampleRate
        let asked = context.expectedEvents.compactMap { event in
            context.frequency(for: event).map {
                (start: event.onsetBeat * secondsPerBeat, duration: event.durationBeats * secondsPerBeat, frequency: $0)
            }
        }
        let strayLimit = min(0.25, 0.4 * (asked.map(\.duration).min() ?? 1))
        let heardNotes = boundaries.enumerated().map { index, start -> HeardNote in
            let end = index + 1 < boundaries.count ? boundaries[index + 1] : finish
            let pitched = pitchedCells(cells, from: start, to: end)
            let settled = pitched.count >= 6 ? Array(pitched.suffix(pitched.count * 6 / 10)) : pitched
            return HeardNote(start: start, end: end, frequency: median(settled.compactMap(\.frequency)),
                             voiced: Double(pitched.count) * cellDuration)
        }
        let pairing = pair(heardNotes, with: asked, strayLimit: strayLimit)
        var pitchedOrdinal = 0
        let results = context.expectedEvents.enumerated().map { index, event -> MelodyNoteResult in
            let start = event.onsetBeat * secondsPerBeat
            let duration = event.durationBeats * secondsPerBeat
            let end = start + duration
            let inset = min(0.10, duration * 0.20)
            let interior = cells.filter { $0.time >= start + inset && $0.time < end - min(0.08, duration * 0.15) }
            let expectedInterior = max(0.01, duration - inset - min(0.08, duration * 0.15))
            let activeCoverage = Double(interior.filter(\.active).count) * cellDuration / expectedInterior
            let expectedFrequency = context.frequency(for: event)
            let onset: Double?
            let segmentEnd: Double?
            if expectedFrequency != nil {
                let note = pairing[pitchedOrdinal].map { heardNotes[$0] }
                onset = note?.start
                segmentEnd = note?.end
                pitchedOrdinal += 1
            } else { onset = nil; segmentEnd = nil }
            // Sequence pitch and clarity use independently detected sound segments;
            // timing still uses absolute movie time. A late, correct sequence can
            // earn Notes without disguising its late starts as correct Timing.
            let heard = onset.flatMap { onset in segmentEnd.map { pitchedCells(cells, from: onset, to: $0) } } ?? []
            // A voice often slides into a note. Its pitch is judged once it has settled:
            // on the last three fifths of what was heard.
            let settled = heard.count >= 6 ? Array(heard.suffix(heard.count * 6 / 10)) : heard
            let voicedCoverage = Double(heard.count) * cellDuration / expectedInterior
            let observedFrequency = median(settled.compactMap(\.frequency))
            let octaveMismatch = observedFrequency.flatMap { measured in expectedFrequency.map {
                let cents = abs(1_200 * log2(measured / $0))
                return abs(cents - 1_200) <= 90
            } } ?? false
            let near = expectedFrequency.map { expected in
                Double(settled.filter { abs(1_200 * log2(($0.frequency ?? 0) / expected)) <= matchCents }.count)
                    / Double(max(1, settled.count))
            } ?? 0
            let restQuiet = activeCoverage <= 0.20
            let matched = expectedFrequency == nil ? restQuiet : voicedCoverage >= 0.35 && near >= 0.75
            let quick = duration < quickNote
            let clear = expectedFrequency == nil ? restQuiet : voicedCoverage >= (quick ? 0.50 : 0.70)
                && median(heard.map(\.confidence)).map { $0 >= 0.85 } == true
            let nearStart = onset.map { abs($0 - start) <= startSlack(noteDuration: duration) } ?? false
            let timed = expectedFrequency == nil ? restQuiet : nearStart && activeCoverage >= (quick ? 0.45 : 0.60)
                && Double(samples.count) / sampleRate >= end - min(0.15, duration * 0.20)
            return MelodyNoteResult(expectedIndex: index, expectedStart: start, expectedDuration: duration,
                expectedFrequency: expectedFrequency, observedFrequency: observedFrequency,
                observedOnset: onset, matched: matched, timed: timed,
                clear: clear, octaveMismatch: octaveMismatch)
        }
        // A heard note that was no asked note counts against sequence and timing, rather than
        // being discarded. A stray, too short to be a note (a slide before a change, a knock),
        // does not: it is kept so the learner can be told about it.
        let unasked = heardNotes.indices.filter { !pairing.contains($0) }
        // A stray is over before it settles, so its pitch is the middle of all that was heard of it.
        let strays = unasked.filter { heardNotes[$0].voiced < strayLimit }.map { index -> MelodyStray in
            let note = heardNotes[index]
            return MelodyStray(time: note.start, frequency: median(cells.filter {
                $0.time >= note.start && $0.time < note.end && !$0.ambiguous
            }.compactMap(\.frequency)))
        }
        let eventCount = Double(results.count + unasked.count - strays.count)
        let matchedFraction = Double(results.filter(\.matched).count) / eventCount
        let timedFraction = Double(results.filter(\.timed).count) / eventCount
        let clearFraction = Double(results.filter(\.clear).count) / Double(results.count)
        let outsideSound = cells.filter { cell in
            cell.active && !context.expectedEvents.contains { event in
                cell.time >= event.onsetBeat * secondsPerBeat && cell.time < event.endBeat * secondsPerBeat
            }
        }.count
        // Fresh starts leave short gaps in the sound, so a take with quick notes may be less voiced.
        let voicedEnough = context.expectedEvents.contains { $0.durationBeats * secondsPerBeat < quickNote } ? 0.65 : 0.80
        let status: MelodyRating.Status
        if voicedDuration < max(0.35, context.duration * 0.12) {
            status = activeDuration >= max(0.35, context.duration * 0.12) ? .unclear : .insufficientSound
        } else if activeDuration == 0 || voicedDuration / activeDuration < 0.55 || ambiguousFraction >= 0.15 {
            status = .unclear
        } else { status = .rated }
        return MelodyRating(status: status, notes: matchedFraction + 1e-9 >= 0.80,
            timing: timedFraction + 1e-9 >= 0.80 && Double(outsideSound) * cellDuration <= 0.15,
            clarity: clearFraction + 1e-9 >= 0.80 && voicedDuration / max(0.001, activeDuration) >= voicedEnough,
            voicedDuration: voicedDuration, matchedNoteFraction: matchedFraction,
            timedNoteFraction: timedFraction, clearNoteFraction: clearFraction,
            octaveMismatch: results.contains(where: \.octaveMismatch), noteResults: results, pitchPoints: points,
            strays: strays.isEmpty ? nil : strays)
    }

    /// One stretch of sound between two note starts.
    private struct HeardNote {
        let start: Double, end: Double
        /// Where its pitch settled; nil when no clear pitch was heard in it.
        let frequency: Double?
        /// How long a clear pitch lasted in it.
        let voiced: Double
    }

    /// A heard note's cells with a clear pitch, away from its edges, where one note blends into the next.
    private static func pitchedCells(_ cells: [Cell], from start: Double, to end: Double) -> [Cell] {
        let length = max(0, end - start)
        return cells.filter {
            $0.time >= start + min(0.10, length * 0.20) && $0.time < end - min(0.08, length * 0.15)
                && $0.frequency != nil && !$0.ambiguous
        }
    }

    /// Pairs the notes heard with the notes asked, each kept in order, at the least cost. Against
    /// an asked note, a heard note costs 1 for the wrong pitch, and up to 1 more as its start moves
    /// from the allowance to a whole note's length away. Leaving an asked note unheard, or a heard
    /// note unasked, costs 1; a stray costs a quarter. So notes sung in time pair with their own
    /// places whatever their pitch, and the right notes sung late still pair note for note,
    /// leaving the lateness for Timing to judge.
    private static func pair(_ heard: [HeardNote], with asked: [(start: Double, duration: Double, frequency: Double)],
                             strayLimit: Double) -> [Int?] {
        func together(_ note: HeardNote, _ target: (start: Double, duration: Double, frequency: Double)) -> Double {
            let pitch = note.frequency.map { abs(1_200 * log2($0 / target.frequency)) <= matchCents ? 0.0 : 1 } ?? 1
            let slack = startSlack(noteDuration: target.duration)
            return pitch + min(1, max(0, abs(note.start - target.start) - slack) / (target.duration - slack))
        }
        // cost[i][j]: the least cost of pairing the first i asked notes with the first j heard ones.
        var cost = [[Double]](repeating: [Double](repeating: .infinity, count: heard.count + 1), count: asked.count + 1)
        cost[0][0] = 0
        for i in 0...asked.count {
            for j in 0...heard.count where i + j > 0 {
                var best = Double.infinity
                if i > 0, j > 0 { best = cost[i - 1][j - 1] + together(heard[j - 1], asked[i - 1]) }
                if i > 0 { best = min(best, cost[i - 1][j] + 1) }
                if j > 0 { best = min(best, cost[i][j - 1] + (heard[j - 1].voiced < strayLimit ? 0.25 : 1)) }
                cost[i][j] = best
            }
        }
        // Walk back from the end, preferring a pair wherever it is as cheap as leaving one out.
        var pairs = [Int?](repeating: nil, count: asked.count)
        var i = asked.count, j = heard.count
        while i > 0 || j > 0 {
            if i > 0, j > 0, cost[i][j] == cost[i - 1][j - 1] + together(heard[j - 1], asked[i - 1]) {
                pairs[i - 1] = j - 1; i -= 1; j -= 1
            } else if i > 0, cost[i][j] == cost[i - 1][j] + 1 { i -= 1 } else { j -= 1 }
        }
        return pairs
    }

    /// How far from its place a note may start and still be on time.
    private static func startSlack(noteDuration: Double) -> Double { min(0.20, noteDuration * 0.35) }

    private struct Frame { let time: Double; let estimate: PitchEstimate?; let ambiguous: Bool }
    private struct Cell {
        let time: Double; let active: Bool; let frequency: Double?
        let confidence: Double; let rms: Double; let ambiguous: Bool
    }

    /// The frames that read an octave away from the sound next to them for 150 ms or
    /// less. A voice cannot leap an octave and back that fast: as a hum fades, its
    /// first overtone can outlast it, and the detector follows the overtone. Such
    /// frames are ambiguous, so they are neither a new note nor a point on the chart.
    static func octaveSlips(in frequencies: [Double?]) -> Set<Int> {
        // Runs of neighbouring frames that stay within a few semitones of each other.
        var runs: [Range<Int>] = []
        for (index, frequency) in frequencies.enumerated() {
            guard let frequency else { continue }
            if let last = runs.last, last.upperBound == index, let previous = frequencies[index - 1],
               abs(1_200 * log2(frequency / previous)) < 300 {
                runs[runs.count - 1] = last.lowerBound..<(index + 1)
            } else { runs.append(index..<(index + 1)) }
        }
        func isOctave(_ first: Int, _ second: Int) -> Bool {
            guard let one = frequencies[first], let other = frequencies[second] else { return false }
            return abs(abs(1_200 * log2(one / other)) - 1_200) <= 120
        }
        var slips = Set<Int>()
        for (index, run) in runs.enumerated() where run.count <= 3 {
            let before = index > 0 ? runs[index - 1] : nil
            let after = index + 1 < runs.count ? runs[index + 1] : nil
            let followsLongerRun = before.map { $0.count > run.count && run.lowerBound - $0.upperBound <= 3
                && isOctave(run.lowerBound, $0.upperBound - 1) } ?? false
            let precedesLongerRun = after.map { $0.count > run.count && $0.lowerBound - run.upperBound <= 3
                && isOctave(run.upperBound - 1, $0.lowerBound) } ?? false
            if followsLongerRun || precedesLongerRun { slips.formUnion(run) }
        }
        return slips
    }

    /// Where notes begin, from the sound: after silence, at a lasting change of pitch, or at a
    /// dip. A dip is the sound falling to under half the note's own level for 30 ms and climbing
    /// most of the way back: how "doo-doo" sounds when the notes are not fully separated. A held
    /// note's level also wanders, so a dip is believed only where the score has a note starting
    /// and nothing has begun there yet. One sustained note still cannot stand in for eight.
    private static func observedBoundaries(cells: [Cell], attackWindowDuration: Double,
                                           noteStarts: [(time: Double, slack: Double)]) -> [Double] {
        var boundaries: [Double] = []
        var inactiveCount = 3
        var previousFrequency: Double?
        var lastAttack: Double?
        // A semitone is nominally 100 cents. Short analysis windows can measure
        // a true semitone a few cents low (97.46 in the quarter-second control).
        let minimumMeasuredStep = 100.0 - 5
        // The level over 30 ms, so one uneven cell is not a dip.
        let levels = cells.indices.map { index -> Double in
            let near = cells[max(0, index - 1)...min(cells.count - 1, index + 1)]
            return near.reduce(0.0) { $0 + $1.rms } / Double(near.count)
        }
        // The note's last 200 ms of level outside any dip; its middle is the note's own level,
        // so the burst that starts a note is not the measure.
        var steady: [Double] = []
        var dip: (cells: Int, level: Double, time: Double)?
        for (index, cell) in cells.enumerated() {
            if !cell.active { inactiveCount += 1; steady.removeAll(); dip = nil; continue }
            var attack = inactiveCount >= 3
            var attackTime = cell.time
            inactiveCount = 0
            if attack {
                steady.removeAll()
                dip = nil
            } else {
                let level = levels[index]
                let usual = steady.isEmpty ? 0 : steady.sorted()[steady.count / 2]
                if let low = dip, low.cells >= 3 {
                    if level >= max(low.level * 2, usual * 0.6) {
                        if noteStarts.contains(where: { start in abs(low.time - start.time) <= start.slack
                            && !boundaries.contains { abs($0 - start.time) <= start.slack } }) {
                            attack = true
                            attackTime = low.time
                        }
                        dip = nil
                        steady.removeAll()
                    } else if level < low.level { dip = (low.cells, level, cell.time) }
                } else if steady.count >= 10, level < usual * 0.5 {
                    dip = dip.map { ($0.cells + 1, min($0.level, level), level < $0.level ? cell.time : $0.time) } ?? (1, level, cell.time)
                } else {
                    dip = nil
                    steady.append(level)
                    if steady.count > 20 { steady.removeFirst() }
                }
            }
            if attack, boundaries.last.map({ attackTime - $0 >= 0.12 }) ?? true {
                boundaries.append(max(0, attackTime - 0.005))
                // The sound came back at this cell: the settling pitch is ignored from here.
                lastAttack = max(0, cell.time - 0.005)
                previousFrequency = cell.frequency
            }
            guard let frequency = cell.frequency, !cell.ambiguous else { continue }
            // The first pitch windows overlap the attack and may still contain
            // the preceding note. Refresh that transient baseline before looking
            // for another change; never create a second onset from its settling.
            if let lastAttack, cell.time - lastAttack < attackWindowDuration {
                previousFrequency = frequency
                continue
            }
            let changed = previousFrequency.map { abs(1_200 * log2(frequency / $0)) >= minimumMeasuredStep } ?? false
            // A change must survive the next 80ms, avoiding transient/glissando spikes.
            let following = cells[index..<min(cells.count, index + 8)].filter {
                $0.active && !$0.ambiguous
            }.compactMap(\.frequency)
            let stable = following.count >= 5 && following.filter {
                abs(1_200 * log2($0 / frequency)) <= 80
            }.count >= 5
            if changed && stable {
                // An attack's early pitch can settle gradually by a semitone
                // without a new note. Confirm a local step rather than comparing
                // only with that old baseline. These windows depend on sound,
                // never the expected score, and do not suppress reattacks.
                // Leave 40ms before the candidate out of the prior median: a
                // 171ms pitch window straddling a real step blends both notes.
                let precedingEnd = max(0, index - 4)
                let preceding = cells[max(0, precedingEnd - 15)..<precedingEnd].filter {
                    $0.active && !$0.ambiguous
                }.compactMap(\.frequency)
                guard preceding.count >= 5, let before = median(preceding),
                      let after = median(following) else { continue }
                guard abs(1_200 * log2(after / before)) >= minimumMeasuredStep else {
                    previousFrequency = after
                    continue
                }
                if boundaries.last.map({ cell.time - $0 >= 0.12 }) ?? true {
                    boundaries.append(max(0, cell.time - 0.005))
                    previousFrequency = frequency
                }
            } else if previousFrequency == nil { previousFrequency = frequency }
        }
        return boundaries
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
