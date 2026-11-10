import Foundation
import XCTest
@testable import Cello

@MainActor
final class MelodyRhythmStoreTests: XCTestCase {
    func testMixedNoteLengthsUseOnsetOffsetsForConsistency() throws {
        for section in MelodySection.allCases {
            let context = try MelodyRhythmContext.hotCrossBuns(section: section)
            let result = try attempt(round(context))
            XCTAssertEqual(result.starCount, 3, section.rawValue)
            XCTAssertEqual(result.matchedTapCount, context.expectedTapTimes.count)
            XCTAssertEqual(result.spreadMilliseconds ?? -1, 0, accuracy: 1e-6)
            XCTAssertEqual(result.medianOffsetMilliseconds ?? -1, 40, accuracy: 1e-6)
        }
    }

    func testPatternRequiresEightyPercentOfOnsetsAndNoHeldNoteExtras() throws {
        let quick = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        XCTAssertEqual(try attempt(round(quick, offsets: Array(repeating: 0.04, count: 7))).starCount, 3)
        let sparse = try attempt(round(quick, offsets: Array(repeating: 0.04, count: 6)))
        XCTAssertEqual(sparse.starCount, 2)
        XCTAssertFalse(sparse.patternGoal)

        let context = try MelodyRhythmContext.hotCrossBuns()
        var timing = round(context)
        timing.recordTap(at: timing.practiceStartTime + 3)
        let result = try attempt(timing)
        XCTAssertEqual(result.unexpectedTapCount, 1)
        XCTAssertEqual(result.totalTaps, 4)
        XCTAssertFalse(result.patternGoal)
        XCTAssertTrue(result.timingGoal)
        XCTAssertTrue(result.consistencyGoal)
        XCTAssertEqual(result.starCount, 2, "An extra beat during the long final note must prevent three stars")
        XCTAssertTrue(result.cue.contains("longer note"))
    }

    func testDuplicateCallbackIsIgnoredButAnotherPressCostsPatternStar() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        var timing = MelodyRhythmTiming(startTime: 100, context: context)
        for onset in context.expectedTapTimes {
            timing.recordTap(at: timing.practiceStartTime + onset + 0.04)
            timing.recordTap(at: timing.practiceStartTime + onset + 0.06)
        }
        XCTAssertEqual(try attempt(timing).starCount, 3)
        timing.recordTap(at: timing.practiceStartTime + 2.1)
        XCTAssertEqual(try attempt(timing).starCount, 2)
        XCTAssertEqual(timing.unexpectedTapCount, 1)
    }

    func testTimingAndConsistencyAreIndependentGoals() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        let late = try attempt(round(context, offsets: [0.2, 0.2, 0.2]))
        XCTAssertTrue(late.patternGoal)
        XCTAssertFalse(late.timingGoal)
        XCTAssertTrue(late.consistencyGoal)
        XCTAssertEqual(late.starCount, 2)

        let varying = try attempt(round(context, offsets: [0.14, -0.14, 0.14]))
        XCTAssertTrue(varying.timingGoal)
        XCTAssertFalse(varying.consistencyGoal)
        XCTAssertEqual(varying.spreadMilliseconds ?? -1, 224, accuracy: 1e-6)
        XCTAssertEqual(varying.starCount, 2)

        let quick = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        let borderline = try attempt(round(quick, offsets: Array(repeating: 0.1, count: 6) + [0.2, 0.2]))
        XCTAssertTrue(borderline.timingGoal)
        XCTAssertEqual(borderline.onTimeFraction, 0.75, accuracy: 1e-8)
        let below = try attempt(round(quick, offsets: Array(repeating: 0.1, count: 5) + [0.2, 0.2, 0.2]))
        XCTAssertFalse(below.timingGoal)
    }

    func testMisplacedRealTapsReceiveZeroStarsAndLuckyHitsCannotEarnOtherGoals() throws {
        let phrase = try MelodyRhythmContext.hotCrossBuns()
        var misplaced = MelodyRhythmTiming(startTime: 100, context: phrase)
        for time in [0.5, 1.5, 3.0] { misplaced.recordTap(at: misplaced.practiceStartTime + time) }
        let result = try attempt(misplaced)
        XCTAssertEqual(result.totalTaps, 3)
        XCTAssertEqual(result.matchedTapCount, 0)
        XCTAssertEqual(result.starCount, 0)
        XCTAssertTrue(result.isScored)
        XCTAssertFalse(result.timingGoal)
        XCTAssertFalse(result.consistencyGoal)
        XCTAssertNil(result.spreadMilliseconds)

        let whole = try MelodyRhythmContext.hotCrossBuns(section: .whole)
        var lucky = MelodyRhythmTiming(startTime: 100, context: whole)
        for time in [0.04, 1.04, 3.0] { lucky.recordTap(at: lucky.practiceStartTime + time) }
        let twoHits = try attempt(lucky)
        XCTAssertEqual(twoHits.matchedTapCount, 2)
        XCTAssertEqual(twoHits.starCount, 0)
    }

    func testSmallGenericTimelineCanBeScoredButAllRestTimelineCannot() throws {
        let original = try MelodyRhythmContext.hotCrossBuns()
        let events = [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 47),
                      MelodyEvent(onsetBeat: 1, durationBeats: 3, midiNote: 45)]
        let small = replacing(original, events: events)
        XCTAssertEqual(try attempt(round(small)).starCount, 3)
        let silence = replacing(original, events: [MelodyEvent(onsetBeat: 0, durationBeats: 4, midiNote: nil)])
        XCTAssertFalse(silence.isValid)
        let timing = MelodyRhythmTiming(startTime: 100, context: silence)
        XCTAssertNil(MelodyRhythmAttempt(timing: timing, finishedAt: timing.endTime))
    }

    func testUnscoredRoundsDoNotConsumeProgressWindow() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let store = MelodyRhythmStore(directory: directory)
        for _ in 0..<2 { finish(round(context), in: store) }
        for _ in 0..<6 { finish(round(context, offsets: [0.04]), in: store) }
        XCTAssertNil(store.latestStars(for: context))
        XCTAssertEqual(store.bestStars(for: context), 3)
        XCTAssertEqual(store.progress(for: context).successfulAttempts, 2)
        XCTAssertFalse(store.progress(for: context).completed)
        XCTAssertNil(try attempt(round(context, offsets: [])).starCount)
        finish(round(context), in: store)
        XCTAssertTrue(store.progress(for: context).completed)
        XCTAssertEqual(store.attempts.count, 9, "Unscored rounds remain in the history")
    }

    func testCompletionUsesFiveScoredRoundsAndSurvivesLaterMissesAndReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let store = MelodyRhythmStore(directory: directory)
        for good in [true, false, true, false, true] {
            finish(round(context, offsets: Array(repeating: good ? 0.04 : 0.2, count: 3)), in: store)
        }
        XCTAssertTrue(store.progress(for: context).completed)
        for _ in 0..<6 { finish(round(context, offsets: [0.2, 0.2, 0.2]), in: store) }
        let bytes = try Data(contentsOf: historyFile(in: directory))
        let reopened = MelodyRhythmStore(directory: directory)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertEqual(reopened.attempts.count, 11)
        XCTAssertTrue(reopened.progress(for: context).completed)
        XCTAssertEqual(reopened.progress(for: context).successfulAttempts, 3)
        XCTAssertEqual(reopened.latestStars(for: context), 2)
        XCTAssertEqual(reopened.bestStars(for: context), 3)
        XCTAssertEqual(try Data(contentsOf: historyFile(in: directory)), bytes, "Reading history must not rewrite it")
    }

    func testOldSuccessesOutsideFiveScoredRoundsDoNotAccumulate() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let store = MelodyRhythmStore(directory: directory)
        for good in [true, true, false, false, false, false, false, true] {
            finish(round(context, offsets: Array(repeating: good ? 0.04 : 0.2, count: 3)), in: store)
        }
        XCTAssertFalse(store.progress(for: context).completed)
        XCTAssertEqual(store.progress(for: context).successfulAttempts, 1)
    }

    func testClockRollbackKeepsRecordingOrderCompletionAndWritableHistory() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let store = MelodyRhythmStore(directory: directory)
        for _ in 0..<3 { finish(round(context), in: store) }
        var document = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: historyFile(in: directory))) as? [String: Any])

        // A real completion at dates 100/200/300, followed by six newer
        // recordings after the device clock moved back to dates 150...155.
        let successes = try [300.0, 200, 100].map {
            try attempt(round(context), createdAt: Date(timeIntervalSince1970: $0))
        }
        let misses = try [155.0, 154, 153, 152, 151, 150].map {
            try attempt(round(context, offsets: [0.2, 0.2, 0.2]),
                        createdAt: Date(timeIntervalSince1970: $0))
        }
        let recordedOrder = misses + successes
        document["attempts"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recordedOrder))
        let original = try JSONSerialization.data(withJSONObject: document)
        try original.write(to: historyFile(in: directory))

        let reopened = MelodyRhythmStore(directory: directory)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertEqual(reopened.attempts.map(\.id), recordedOrder.map(\.id))
        XCTAssertEqual(reopened.latestStars(for: context), 2)
        XCTAssertTrue(reopened.progress(for: context).completed)
        XCTAssertEqual(try Data(contentsOf: historyFile(in: directory)), original)

        let id = UUID()
        let timing = round(context, offsets: [0.2, 0.2, 0.2])
        XCTAssertNotNil(reopened.record(timing: timing, at: timing.endTime, id: id))
        XCTAssertNil(reopened.errorMessage, "Clock rollback must not put the file into read-only recovery")
        let savedOrder = [id] + recordedOrder.map(\.id)
        XCTAssertEqual(reopened.attempts.map(\.id), savedOrder)
        let reloaded = MelodyRhythmStore(directory: directory)
        XCTAssertNil(reloaded.errorMessage)
        XCTAssertEqual(reloaded.attempts.map(\.id), savedOrder)
        XCTAssertTrue(reloaded.progress(for: context).completed)
    }

    func testPhraseTempoScoreAndRhythmHaveSeparateProgressButVoiceRegisterDoesNot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let store = MelodyRhythmStore(directory: directory)
        for _ in 0..<3 { finish(round(context), in: store) }
        XCTAssertTrue(store.progress(for: context).completed)
        let differentContexts = [
            try MelodyRhythmContext.hotCrossBuns(section: .phrase2),
            try MelodyRhythmContext.hotCrossBuns(tempoBPM: 72),
            replacing(context, scoreVersion: 2),
            replacing(context, durationBeats: 5),
            replacing(context, events: [MelodyEvent(onsetBeat: 0, durationBeats: 0.5, midiNote: 47),
                                       MelodyEvent(onsetBeat: 0.5, durationBeats: 1.5, midiNote: 45),
                                       MelodyEvent(onsetBeat: 2, durationBeats: 2, midiNote: 43)]),
            replacing(context, events: [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: nil),
                                       MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: 45),
                                       MelodyEvent(onsetBeat: 2, durationBeats: 2, midiNote: 43)]),
            MelodyRhythmContext(reference: context.reference, scoringVersion: 2)
        ]
        for other in differentContexts {
            XCTAssertFalse(store.progress(for: other).completed)
            XCTAssertEqual(store.progress(for: other).successfulAttempts, 0)
            XCTAssertNil(store.bestStars(for: other))
        }
        for register in [MelodyRegister.higherVoice, .cello] {
            let transposed = MelodyRhythmContext(reference: try .hotCrossBuns(register: register, section: .phrase1))
            XCTAssertTrue(store.progress(for: transposed).completed, "Rhythm achievement must not depend on humming register")
        }
        let reopened = MelodyRhythmStore(directory: directory)
        XCTAssertTrue(reopened.progress(for: context).completed)
        XCTAssertFalse(reopened.progress(for: differentContexts[0]).completed)
    }

    func testUnfinishedInvalidAndFutureVersionRoundsCannotSaveAndRoundIDsAreIdempotent() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let timing = round(context)
        let store = MelodyRhythmStore(directory: directory)
        XCTAssertNil(store.record(timing: timing, at: timing.endTime - 0.001))
        XCTAssertNil(store.record(timing: timing, at: .infinity))
        for start in [Double.nan, .infinity, -1, .greatestFiniteMagnitude] {
            let invalid = MelodyRhythmTiming(startTime: start, context: context)
            XCTAssertNil(store.record(timing: invalid, at: 1_000))
        }
        let future = round(MelodyRhythmContext(reference: context.reference, scoringVersion: 2))
        XCTAssertNil(store.record(timing: future, at: future.endTime))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        let id = UUID()
        let result = store.record(timing: timing, at: timing.endTime, id: id)
        XCTAssertEqual(result?.starCount, 3)
        XCTAssertEqual(store.record(timing: timing, at: timing.endTime + 1, id: id), result)
        let other = round(try .hotCrossBuns(section: .phrase2))
        XCTAssertNil(store.record(timing: other, at: other.endTime, id: id))
        XCTAssertEqual(store.attempts.count, 1)
        XCTAssertEqual(MelodyRhythmStore(directory: directory).attempts.count, 1)
    }

    func testFrozenRatingAndObservedTapTimelineRoundTrip() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        var timing = round(context)
        timing.recordTap(at: timing.practiceStartTime + 3)
        let original = try attempt(timing)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MelodyRhythmAttempt.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.context, context)
        XCTAssertEqual(decoded.actualTapTimes.count, 4)
        XCTAssertEqual(decoded.starCount, 2)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["rating"], "The version-one goals must be frozen in the document")
    }

    func testCorruptUnsupportedOrTamperedHistoryIsPreservedWithoutProgress() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        let baseline = try historyObject([attempt(round(context))])
        var documents: [Data] = [Data("not JSON".utf8)]
        var schema = baseline
        schema["schemaVersion"] = 2
        documents.append(try JSONSerialization.data(withJSONObject: schema))
        var duplicated = baseline
        let originalAttempts = try XCTUnwrap(baseline["attempts"] as? [[String: Any]])
        duplicated["attempts"] = originalAttempts + originalAttempts
        documents.append(try JSONSerialization.data(withJSONObject: duplicated))
        for mutation in ["offsets", "actualTapTimes", "rating", "scoringVersion", "voiceGradingVersion"] {
            var object = baseline
            var attempts = originalAttempts
            var saved = attempts[0]
            switch mutation {
            case "offsets": saved["offsets"] = ["99": 0.04]
            case "actualTapTimes": saved["actualTapTimes"] = [0.04, 0.05, 2.04]
            case "rating":
                var rating = try XCTUnwrap(saved["rating"] as? [String: Any])
                rating["pattern"] = false
                saved["rating"] = rating
            default:
                var snapshot = try XCTUnwrap(saved["context"] as? [String: Any])
                if mutation == "scoringVersion" { snapshot["scoringVersion"] = 2 }
                else {
                    var reference = try XCTUnwrap(snapshot["reference"] as? [String: Any])
                    reference["gradingVersion"] = 1
                    snapshot["reference"] = reference
                }
                saved["context"] = snapshot
            }
            attempts[0] = saved
            object["attempts"] = attempts
            documents.append(try JSONSerialization.data(withJSONObject: object))
        }
        var unearned = baseline
        unearned["completedKeys"] = [String(repeating: "a", count: 64)]
        documents.append(try JSONSerialization.data(withJSONObject: unearned))

        for original in documents {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try original.write(to: historyFile(in: directory))
            let store = MelodyRhythmStore(directory: directory)
            XCTAssertNotNil(store.errorMessage)
            let result = finish(round(context), in: store)
            XCTAssertEqual(result?.starCount, 3, "The current result can still be shown")
            XCTAssertTrue(store.attempts.isEmpty)
            XCTAssertFalse(store.progress(for: context).completed)
            XCTAssertEqual(store.progress(for: context).successfulAttempts, 0)
            XCTAssertEqual(try Data(contentsOf: historyFile(in: directory)), original)
        }
    }

    func testWriteFailureReturnsResultWithoutInventingProgressAndRetryCanSave() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try MelodyRhythmContext.hotCrossBuns()
        let timing = round(context)
        let store = MelodyRhythmStore(directory: directory)
        try FileManager.default.createDirectory(at: historyFile(in: directory), withIntermediateDirectories: true)
        let id = UUID()
        XCTAssertEqual(store.record(timing: timing, at: timing.endTime, id: id)?.starCount, 3)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.attempts.isEmpty)
        XCTAssertEqual(store.progress(for: context).successfulAttempts, 0)
        try FileManager.default.removeItem(at: historyFile(in: directory))
        XCTAssertEqual(store.record(timing: timing, at: timing.endTime, id: id)?.starCount, 3)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.attempts.count, 1)
        XCTAssertEqual(store.progress(for: context).successfulAttempts, 1)
        XCTAssertEqual(MelodyRhythmStore(directory: directory).attempts.count, 1)
    }

    func testNewHistoryNeverTouchesFoundationOrVoiceFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let names = ["PulsePractice.json", "TwoTapsPractice.json", "MixedRhythmPractice.json",
                     "PracticeProgress.json", "MelodyProgress.json"]
        let sentinel = Data("Existing private practice history".utf8)
        for name in names { try sentinel.write(to: directory.appendingPathComponent(name)) }
        let store = MelodyRhythmStore(directory: directory)
        finish(round(try .hotCrossBuns()), in: store)
        for name in names { XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(name)), sentinel) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: historyFile(in: directory).path))
    }

    private func round(_ context: MelodyRhythmContext, offsets: [Double]? = nil) -> MelodyRhythmTiming {
        var timing = MelodyRhythmTiming(startTime: 100, context: context)
        let offsets = offsets ?? Array(repeating: 0.04, count: context.expectedTapTimes.count)
        for (index, offset) in offsets.enumerated() {
            timing.recordTap(at: timing.practiceStartTime + context.expectedTapTimes[index] + offset)
        }
        return timing
    }

    private func attempt(_ timing: MelodyRhythmTiming, createdAt: Date = Date()) throws -> MelodyRhythmAttempt {
        try XCTUnwrap(MelodyRhythmAttempt(timing: timing, finishedAt: timing.endTime, createdAt: createdAt))
    }

    @discardableResult
    private func finish(_ timing: MelodyRhythmTiming, in store: MelodyRhythmStore) -> MelodyRhythmAttempt? {
        store.record(timing: timing, at: timing.endTime)
    }

    private func replacing(_ context: MelodyRhythmContext, scoreVersion: Int? = nil,
                           durationBeats: Double? = nil, events: [MelodyEvent]? = nil) -> MelodyRhythmContext {
        let source = context.reference
        return MelodyRhythmContext(reference: MelodyPracticeContext(
            pieceID: source.pieceID, scoreVersion: scoreVersion ?? source.scoreVersion,
            register: source.register, referenceKey: source.referenceKey, tuningA4Hz: source.tuningA4Hz,
            tempoBPM: source.tempoBPM, section: source.section, expectedEvents: events ?? source.expectedEvents,
            durationBeats: durationBeats ?? source.durationBeats, gradingVersion: nil))
    }

    private func historyObject(_ attempts: [MelodyRhythmAttempt]) throws -> [String: Any] {
        let data = try JSONEncoder().encode(attempts)
        return ["schemaVersion": 1, "attempts": try JSONSerialization.jsonObject(with: data),
                "completedKeys": [String]()]
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MelodyRhythmStoreTests-\(UUID().uuidString)")
    }

    private func historyFile(in directory: URL) -> URL {
        directory.appendingPathComponent("MelodyRhythmPractice.json")
    }
}
