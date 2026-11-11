import Foundation
import XCTest
@testable import Cello

@MainActor
final class PulsePracticeStoreTests: XCTestCase {
    func testThreeGoalsMeasureCoverageTimingAndEvennessSeparately() throws {
        let complete = try attempt(offsets: Array(repeating: 0.04, count: 16))
        XCTAssertEqual(complete.starCount, 3)

        let missed = try attempt(offsets: Array(repeating: 0, count: 11))
        XCTAssertFalse(missed.beatsGoal)
        XCTAssertTrue(missed.timingGoal)
        XCTAssertTrue(missed.evennessGoal)
        XCTAssertEqual(missed.starCount, 2)

        let enough = try attempt(offsets: Array(repeating: 0, count: 12))
        XCTAssertEqual(enough.starCount, 3)

        // Consistently early taps can be even without landing on the pulse.
        let early = try attempt(offsets: Array(repeating: -0.23, count: 16))
        XCTAssertTrue(early.beatsGoal)
        XCTAssertFalse(early.timingGoal)
        XCTAssertTrue(early.evennessGoal)
        XCTAssertEqual(early.starCount, 2)

        // Every tap is reasonably close, but their spacing keeps changing.
        let uneven = try attempt(offsets: (0..<16).map { $0.isMultiple(of: 2) ? -0.14 : 0.14 })
        XCTAssertTrue(uneven.timingGoal)
        XCTAssertFalse(uneven.evennessGoal)
        XCTAssertEqual(uneven.starCount, 2)
    }

    func testTimingRequiresThreeQuartersOfAcceptedTapsOnThePulse() throws {
        let borderline = try attempt(offsets: Array(repeating: 0.10, count: 12) + Array(repeating: 0.3, count: 4))
        XCTAssertTrue(borderline.timingGoal)
        XCTAssertEqual(borderline.onTimeFraction, 0.75, accuracy: 1e-8)
        let below = try attempt(offsets: Array(repeating: 0.10, count: 11) + Array(repeating: 0.3, count: 5))
        XCTAssertFalse(below.timingGoal)
    }

    func testFewTapsAreUnscoredAndDoNotConsumeProgressWindow() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PulsePracticeStore(directory: directory)
        for _ in 0..<2 { finish(goodTiming(), in: store) }
        for _ in 0..<6 { finish(timing(offsets: [0, 0]), in: store) }
        XCTAssertNil(store.latestStars)
        XCTAssertEqual(store.bestStars, 3)
        XCTAssertEqual(store.progress.successfulAttempts, 2)
        XCTAssertFalse(store.progress.completed)
        XCTAssertNil(try attempt(offsets: []).starCount)
        finish(goodTiming(), in: store)
        XCTAssertTrue(store.progress.completed)
    }

    func testThreeStrongRoundsAmongFiveEarnCompletionAndSurviveLaterMissesAndRelaunch() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PulsePracticeStore(directory: directory)
        for success in [true, false, true, false, true] {
            finish(success ? goodTiming() : timing(offsets: Array(repeating: 0.3, count: 16)), in: store)
        }
        XCTAssertTrue(store.progress.completed)
        XCTAssertEqual(store.progress.successfulAttempts, 3)
        for _ in 0..<6 { finish(timing(offsets: Array(repeating: 0.3, count: 16)), in: store) }

        let reopened = PulsePracticeStore(directory: directory)
        XCTAssertEqual(reopened.attempts.count, 11)
        XCTAssertTrue(reopened.progress.completed)
        XCTAssertEqual(reopened.progress.successfulAttempts, 3)
        XCTAssertEqual(reopened.bestStars, 3)
        XCTAssertEqual(reopened.latestStars, 2)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("PracticeProgress.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("PracticeSessions").path))
    }

    func testOldSuccessesOutsideFiveScoredRoundsDoNotAccumulate() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PulsePracticeStore(directory: directory)
        for success in [true, true, false, false, false, false, false, true] {
            finish(success ? goodTiming() : timing(offsets: Array(repeating: 0.3, count: 16)), in: store)
        }
        XCTAssertFalse(store.progress.completed)
        XCTAssertEqual(store.progress.successfulAttempts, 1)
    }

    func testUnfinishedCancelledOrInvalidRoundsCannotEarnAttemptsAndFinishIsIdempotent() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PulsePracticeStore(directory: directory)
        let round = goodTiming()
        XCTAssertNil(store.record(timing: round, at: round.endTime - 0.01))
        XCTAssertNil(store.record(timing: round, at: .infinity))
        XCTAssertNil(store.record(timing: PulseTiming(startTime: .nan), at: 200))
        XCTAssertTrue(store.attempts.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("PulsePractice.json").path))

        let id = UUID()
        XCTAssertNotNil(store.record(timing: round, at: round.endTime, id: id))
        XCTAssertNotNil(store.record(timing: round, at: round.endTime + 1, id: id))
        XCTAssertEqual(store.attempts.count, 1)
        XCTAssertEqual(store.progress.successfulAttempts, 1)
        XCTAssertEqual(PulsePracticeStore(directory: directory).attempts.count, 1)
    }

    func testCorruptAndUnsupportedHistoryIsPreservedAndCannotBeOverwritten() throws {
        for content in ["not JSON", "{\"schemaVersion\":2,\"attempts\":[],\"completed\":true}"] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("PulsePractice.json")
            let original = Data(content.utf8)
            try original.write(to: file)
            let store = PulsePracticeStore(directory: directory)
            XCTAssertNotNil(store.errorMessage)
            finish(goodTiming(), in: store)
            XCTAssertTrue(store.attempts.isEmpty)
            XCTAssertFalse(store.progress.completed)
            XCTAssertEqual(try Data(contentsOf: file), original)
        }
    }

    func testWriteFailureShowsResultWithoutGrantingUnsavedProgress() throws {
        let file = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("occupied".utf8).write(to: file)
        let store = PulsePracticeStore(directory: file)
        let round = goodTiming()
        let result = store.record(timing: round, at: round.endTime)
        XCTAssertEqual(result?.starCount, 3)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.attempts.isEmpty)
        XCTAssertEqual(store.progress.successfulAttempts, 0)
        XCTAssertFalse(store.progress.completed)
    }

    func testLegacyPulseHistoryWithoutExerciseKeepsGradesCompletionAndOriginalBytes() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rounds = try [attempt(offsets: Array(repeating: 0.3, count: 16))]
            + (0..<3).map { _ in try attempt(offsets: Array(repeating: 0.04, count: 16)) }
        let original = try historyData(rounds, completed: true, legacy: true)
        let file = directory.appendingPathComponent(RhythmExercise.pulse.fileName)
        try original.write(to: file)

        let restored = PulsePracticeStore(directory: directory)
        XCTAssertNil(restored.errorMessage)
        XCTAssertEqual(restored.attempts.count, 4)
        XCTAssertTrue(restored.attempts.allSatisfy { $0.exercise == .pulse })
        XCTAssertEqual(restored.attempts.map(\.starCount), [2, 3, 3, 3])
        XCTAssertEqual(restored.latestStars, 2)
        XCTAssertEqual(restored.bestStars, 3)
        XCTAssertTrue(restored.progress.completed)
        XCTAssertEqual(try Data(contentsOf: file), original, "Opening legacy history must not rewrite it")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(RhythmExercise.twoTaps.fileName).path))
    }

    func testTwoTapsAndPulseUseSeparateFilesAndCompletionWindows() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pulse = PulsePracticeStore(directory: directory)
        let twoTaps = PulsePracticeStore(directory: directory, exercise: .twoTaps)
        for _ in 0..<2 { finish(goodTiming(), in: pulse) }
        let pulseFile = directory.appendingPathComponent(RhythmExercise.pulse.fileName)
        let pulseBytes = try Data(contentsOf: pulseFile)
        for _ in 0..<3 { finish(goodTiming(exercise: .twoTaps), in: twoTaps) }
        XCTAssertEqual(pulse.progress.successfulAttempts, 2)
        XCTAssertFalse(pulse.progress.completed)
        XCTAssertTrue(twoTaps.progress.completed)
        XCTAssertEqual(try Data(contentsOf: pulseFile), pulseBytes)
        for _ in 0..<6 { finish(timing(offsets: Array(repeating: 0.2, count: 16), exercise: .twoTaps), in: twoTaps) }

        let reopenedPulse = PulsePracticeStore(directory: directory)
        let reopenedTwoTaps = PulsePracticeStore(directory: directory, exercise: .twoTaps)
        XCTAssertEqual(reopenedPulse.attempts.count, 2)
        XCTAssertFalse(reopenedPulse.progress.completed)
        XCTAssertEqual(reopenedTwoTaps.attempts.count, 9)
        XCTAssertTrue(reopenedTwoTaps.progress.completed)
        XCTAssertEqual(reopenedTwoTaps.latestStars, 2)
        XCTAssertTrue(reopenedTwoTaps.attempts.allSatisfy { $0.exercise == .twoTaps })
        finish(goodTiming(), in: reopenedPulse)
        XCTAssertTrue(reopenedPulse.progress.completed)
    }

    func testStoresRejectFinishedRoundsFromTheOtherExercise() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for exercise in RhythmExercise.allCases {
            let store = PulsePracticeStore(directory: directory, exercise: exercise)
            for foreign in RhythmExercise.allCases where foreign != exercise {
                let round = goodTiming(exercise: foreign)
                XCTAssertNil(store.record(timing: round, at: round.endTime))
            }
            XCTAssertTrue(store.attempts.isEmpty)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testMixedExerciseHistoryIsPreservedWithoutGrantingCompletionOrOverwriting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = try historyData([
            attempt(offsets: Array(repeating: 0.04, count: 16)),
            attempt(offsets: Array(repeating: 0.04, count: 16), exercise: .twoTaps)
        ], completed: true)
        for exercise in RhythmExercise.allCases {
            let file = directory.appendingPathComponent(exercise.fileName)
            try original.write(to: file)
            let store = PulsePracticeStore(directory: directory, exercise: exercise)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertTrue(store.attempts.isEmpty)
            XCTAssertFalse(store.progress.completed)
            finish(goodTiming(exercise: exercise), in: store)
            XCTAssertEqual(try Data(contentsOf: file), original)
            XCTAssertTrue(store.attempts.isEmpty)
        }
    }

    func testTwoTapsHistoryRejectsOffsetsOutsideItsOwnWindow() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let widePulse = try attempt(offsets: Array(repeating: 0.3, count: 16))
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: historyData([widePulse])) as? [String: Any])
        var attempts = try XCTUnwrap(document["attempts"] as? [[String: Any]])
        attempts[0]["exercise"] = RhythmExercise.twoTaps.rawValue
        document["attempts"] = attempts
        let original = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
        let file = directory.appendingPathComponent(RhythmExercise.twoTaps.fileName)
        try original.write(to: file)

        let store = PulsePracticeStore(directory: directory, exercise: .twoTaps)
        XCTAssertNotNil(store.errorMessage)
        finish(goodTiming(exercise: .twoTaps), in: store)
        XCTAssertTrue(store.attempts.isEmpty)
        XCTAssertFalse(store.progress.completed)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testMixedRhythmPatternGoalRequiresCoverageAndLeavingIntentionalSpaces() throws {
        let correct = try attempt(offsets: Array(repeating: 0.04, count: 12), exercise: .mixedRhythm)
        XCTAssertEqual(correct.totalBeats, 12)
        XCTAssertEqual(correct.starCount, 3)
        let enough = try attempt(offsets: Array(repeating: 0.04, count: 9), exercise: .mixedRhythm)
        XCTAssertEqual(enough.starCount, 3)
        let sparse = try attempt(offsets: Array(repeating: 0.04, count: 8), exercise: .mixedRhythm)
        XCTAssertEqual(sparse.starCount, 2)
        XCTAssertFalse(sparse.beatsGoal)

        var oneStray = goodTiming(exercise: .mixedRhythm)
        oneStray.recordTap(at: 104.5)
        XCTAssertEqual(try XCTUnwrap(PulseAttempt(timing: oneStray, finishedAt: oneStray.endTime)).starCount, 3)
        var allEighthNotes = PulseTiming(startTime: 100, exercise: .mixedRhythm)
        for slot in 0..<16 { allEighthNotes.recordTap(at: 104 + Double(slot) / 2) }
        let wrongPattern = try XCTUnwrap(PulseAttempt(timing: allEighthNotes, finishedAt: allEighthNotes.endTime))
        XCTAssertEqual(wrongPattern.tapCount, 12)
        XCTAssertEqual(wrongPattern.unexpectedTapCount, 4)
        XCTAssertFalse(wrongPattern.beatsGoal)
        XCTAssertTrue(wrongPattern.timingGoal)
        XCTAssertTrue(wrongPattern.evennessGoal)
        XCTAssertEqual(wrongPattern.starCount, 2, "Continuing Lesson 4's rhythm must not complete Lesson 5")
        XCTAssertTrue(wrongPattern.cue.contains("Beats 1, 3, 5 and 7 get one tap"))
    }

    func testMixedRhythmHistoryProgressAndUnexpectedTapsStayInTheirOwnFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pulse = PulsePracticeStore(directory: directory)
        let twoTaps = PulsePracticeStore(directory: directory, exercise: .twoTaps)
        for _ in 0..<2 { finish(goodTiming(), in: pulse) }
        for _ in 0..<3 { finish(goodTiming(exercise: .twoTaps), in: twoTaps) }
        let pulseFile = directory.appendingPathComponent(RhythmExercise.pulse.fileName)
        let twoTapsFile = directory.appendingPathComponent(RhythmExercise.twoTaps.fileName)
        let pulseBytes = try Data(contentsOf: pulseFile)
        let twoTapsBytes = try Data(contentsOf: twoTapsFile)
        let mixed = PulsePracticeStore(directory: directory, exercise: .mixedRhythm)
        var wrongPattern = PulseTiming(startTime: 100, exercise: .mixedRhythm)
        for slot in 0..<16 { wrongPattern.recordTap(at: 104 + Double(slot) / 2) }
        finish(wrongPattern, in: mixed)
        for _ in 0..<3 { finish(goodTiming(exercise: .mixedRhythm), in: mixed) }
        XCTAssertTrue(mixed.progress.completed)
        XCTAssertEqual(mixed.progress.successfulAttempts, 3)
        XCTAssertFalse(pulse.progress.completed)
        XCTAssertTrue(twoTaps.progress.completed)
        XCTAssertEqual(try Data(contentsOf: pulseFile), pulseBytes)
        XCTAssertEqual(try Data(contentsOf: twoTapsFile), twoTapsBytes)

        let reopened = PulsePracticeStore(directory: directory, exercise: .mixedRhythm)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertTrue(reopened.progress.completed)
        XCTAssertEqual(reopened.attempts.count, 4)
        XCTAssertEqual(reopened.attempts.last?.unexpectedTapCount, 4)
        XCTAssertEqual(reopened.attempts.last?.starCount, 2)
        XCTAssertEqual(reopened.latestStars, 3)
    }

    func testNegativeUnexpectedCountsAndNonMixedUnexpectedCountsPreserveUnreadableHistory() throws {
        for (exercise, count) in [(RhythmExercise.mixedRhythm, -1), (.pulse, 1), (.twoTaps, 1)] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let round = try XCTUnwrap(PulseAttempt(timing: goodTiming(exercise: exercise), finishedAt: 120))
            var document = try XCTUnwrap(JSONSerialization.jsonObject(with: historyData([round])) as? [String: Any])
            var attempts = try XCTUnwrap(document["attempts"] as? [[String: Any]])
            attempts[0]["unexpectedTapCount"] = count
            document["attempts"] = attempts
            let original = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
            let file = directory.appendingPathComponent(exercise.fileName)
            try original.write(to: file)
            let store = PulsePracticeStore(directory: directory, exercise: exercise)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertTrue(store.attempts.isEmpty)
            finish(goodTiming(exercise: exercise), in: store)
            XCTAssertEqual(try Data(contentsOf: file), original)
        }
    }

    private func attempt(offsets: [TimeInterval], exercise: RhythmExercise = .pulse) throws -> PulseAttempt {
        let round = timing(offsets: offsets, exercise: exercise)
        return try XCTUnwrap(PulseAttempt(timing: round, finishedAt: round.endTime))
    }

    private func goodTiming(exercise: RhythmExercise = .pulse) -> PulseTiming {
        timing(offsets: Array(repeating: 0.04, count: exercise.tapCount), exercise: exercise)
    }

    private func timing(offsets: [TimeInterval], exercise: RhythmExercise = .pulse) -> PulseTiming {
        var round = PulseTiming(startTime: 100, exercise: exercise)
        XCTAssertLessThanOrEqual(offsets.count, exercise.tapCount)
        for (tap, offset) in offsets.enumerated() {
            XCTAssertTrue(round.recordTap(at: 100 + Double(PulseTiming.countInBeats)
                                           + exercise.tapTimes[tap] + offset))
        }
        return round
    }

    private func historyData(_ attempts: [PulseAttempt], completed: Bool = false,
                             legacy: Bool = false) throws -> Data {
        let encoded = try JSONEncoder().encode(attempts)
        var records = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        if legacy {
            for index in records.indices {
                records[index].removeValue(forKey: "exercise")
                records[index].removeValue(forKey: "unexpectedTapCount")
            }
        }
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "attempts": records, "completed": completed
        ], options: [.sortedKeys])
    }

    private func finish(_ timing: PulseTiming, in store: PulsePracticeStore) {
        XCTAssertNotNil(store.record(timing: timing, at: timing.endTime))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PulsePracticeTests-\(UUID().uuidString)")
    }
}
