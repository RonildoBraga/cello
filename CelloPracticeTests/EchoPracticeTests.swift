import CelloPitch
import CryptoKit
import Foundation
import XCTest
@testable import Cello

final class EchoPracticeTests: XCTestCase {
    func testEveryOriginalPatternHasTheFrozenVoiceScoreAndRoundTrips() throws {
        for (level, count) in [(EchoLevel.twoNotes, 6), (.threeNotes, 12)] {
            XCTAssertEqual(level.patternCount, count)
            for register in [MelodyRegister.lowVoice, .higherVoice] {
                var sequences: Set<[Int]> = []
                for index in 0..<count {
                    let context = try level.context(patternIndex: index, register: register)
                    XCTAssertTrue(context.isValid)
                    XCTAssertEqual(context.pieceID, level.pieceID)
                    XCTAssertEqual(context.scoreVersion, EchoLevel.scoreVersion)
                    XCTAssertEqual(context.section, .whole)
                    XCTAssertEqual(context.tempoBPM, 60)
                    XCTAssertEqual(context.tuningA4Hz, 440)
                    XCTAssertEqual(context.gradingVersion, MelodyRating.currentVersion)
                    XCTAssertEqual(context.expectedEvents.count, level.noteCount)
                    XCTAssertEqual(context.expectedEvents.map(\.onsetBeat), (0..<level.noteCount).map { Double($0 * 2) })
                    XCTAssertEqual(context.expectedEvents.map(\.durationBeats), Array(repeating: 2, count: level.noteCount))
                    XCTAssertEqual(context.duration, Double(level.noteCount * 2))
                    XCTAssertEqual(context.expectedEvents.last?.endBeat, context.durationBeats)
                    let restored = try JSONDecoder().decode(MelodyPracticeContext.self,
                        from: JSONEncoder().encode(context))
                    XCTAssertEqual(restored, context)
                    XCTAssertEqual(EchoLevel.selection(for: restored)?.level, level)
                    XCTAssertEqual(EchoLevel.selection(for: restored)?.patternIndex, index)
                    sequences.insert(context.expectedEvents.compactMap(\.midiNote))
                }
                XCTAssertEqual(sequences.count, count, "A fresh index must represent a different pitch pattern")
            }
        }
    }

    func testPatternsIncludeRepeatedRisingAndFallingNotesWithinTheirVoiceRange() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            var directions: Set<Int> = []
            for index in 0..<EchoLevel.twoNotes.patternCount {
                let context = try EchoLevel.twoNotes.context(patternIndex: index, register: register)
                let notes = context.expectedEvents.compactMap(\.midiNote)
                let difference = notes[1] - notes[0]
                directions.insert(difference == 0 ? 0 : difference > 0 ? 1 : -1)
                XCTAssertTrue(notes.allSatisfy { (43 + (register == .higherVoice ? 12 : 0)...47 + (register == .higherVoice ? 12 : 0)).contains($0) })
            }
            XCTAssertEqual(directions, [-1, 0, 1])
            var heard: Set<Int> = []
            for index in 0..<EchoLevel.threeNotes.patternCount {
                let notes = try EchoLevel.threeNotes.context(patternIndex: index, register: register)
                    .expectedEvents.compactMap(\.midiNote)
                heard.formUnion(notes)
                for pair in zip(notes, notes.dropFirst()) { XCTAssertLessThanOrEqual(abs(pair.1 - pair.0), 2) }
            }
            XCTAssertEqual(heard, Set([43, 45, 47, 48, 50].map { $0 + (register == .higherVoice ? 12 : 0) }))
        }
        XCTAssertEqual(EchoLevel.twoNotes.rangeLabel(for: .lowVoice), "G2–B2")
        XCTAssertEqual(EchoLevel.twoNotes.rangeLabel(for: .higherVoice), "G3–B3")
        XCTAssertEqual(EchoLevel.threeNotes.rangeLabel(for: .lowVoice), "G2–D3")
        XCTAssertEqual(EchoLevel.threeNotes.rangeLabel(for: .higherVoice), "G3–D4")
        XCTAssertEqual(EchoLevel.twoNotes.rangeLabel(for: .cello), "D3–F♯3")
        XCTAssertEqual(EchoLevel.threeNotes.rangeLabel(for: .cello), "D3–A3")
    }

    func testFreshPatternSelectionNeverRepeatsThePreviousValidIndex() {
        for level in EchoLevel.allCases {
            var generator = SeededGenerator(state: 42)
            for excluded in 0..<level.patternCount {
                for _ in 0..<100 {
                    let next = level.nextPatternIndex(excluding: excluded, using: &generator)
                    XCTAssertTrue((0..<level.patternCount).contains(next))
                    XCTAssertNotEqual(next, excluded)
                }
            }
            for invalid in [Int?.none, -1, level.patternCount, Int.max] {
                let next = level.nextPatternIndex(excluding: invalid, using: &generator)
                XCTAssertTrue((0..<level.patternCount).contains(next))
            }
        }
    }

    func testInvalidPatternCannotCreateAnEchoTargetInAnyRegister() {
        for level in EchoLevel.allCases {
            for index in [Int.min, -1, level.patternCount, Int.max] {
                XCTAssertThrowsError(try level.context(patternIndex: index, register: .lowVoice))
                XCTAssertThrowsError(try level.context(patternIndex: index, register: .cello))
            }
            XCTAssertNoThrow(try level.context(patternIndex: 0, register: .cello))
        }
    }

    func testSelectionRejectsChangedFrozenFieldsAndOtherMelodies() throws {
        let current = try EchoLevel.twoNotes.context(patternIndex: 1, register: .lowVoice)
        for version in [1, 2] {
            let original = replacing(current, gradingVersion: version)
            let changed = [
                replacing(original, pieceID: "echoTwoNotesOther"), replacing(original, scoreVersion: 2),
                replacing(original, register: .higherVoice), replacing(original, key: "D major"),
                replacing(original, tuning: 441), replacing(original, tempo: 72),
                replacing(original, section: .phrase1), replacing(original, duration: 5),
                replacing(original, gradingVersion: 99),
                replacing(original, events: original.expectedEvents.map {
                    MelodyEvent(onsetBeat: $0.onsetBeat, durationBeats: $0.durationBeats,
                                midiNote: $0.midiNote.map { $0 + 1 })
                }),
                replacing(original, events: [MelodyEvent(onsetBeat: 0, durationBeats: 1.5, midiNote: 43),
                                             MelodyEvent(onsetBeat: 2, durationBeats: 2, midiNote: 45)]),
                try .hotCrossBuns(register: .lowVoice, section: .phrase1, gradingVersion: version),
                try .odeToJoy(register: .lowVoice, section: .phrase1, gradingVersion: version)
            ]
            for context in changed { XCTAssertNil(EchoLevel.selection(for: context), "\(context)") }
        }
        let ungraded = MelodyPracticeContext(pieceID: current.pieceID, scoreVersion: current.scoreVersion,
            register: current.register, referenceKey: current.referenceKey, tuningA4Hz: current.tuningA4Hz,
            tempoBPM: current.tempoBPM, section: current.section, expectedEvents: current.expectedEvents,
            durationBeats: current.durationBeats, gradingVersion: nil)
        XCTAssertNil(EchoLevel.selection(for: ungraded))
    }

    func testHistoricalVersionOnePatternsRetainTheirIdentityTitleAndSavedFeedback() throws {
        XCTAssertEqual(MelodyRating.currentVersion, 4)
        for level in EchoLevel.allCases {
            for register in [MelodyRegister.lowVoice, .higherVoice] {
                for index in 0..<level.patternCount {
                    let context = replacing(try level.context(patternIndex: index, register: register),
                                            gradingVersion: 1)
                    let archived = try session(at: index, context: context, version: 1)
                    let restored = try JSONDecoder().decode(PracticeSession.self,
                        from: JSONEncoder().encode(archived))
                    XCTAssertEqual(EchoLevel.selection(for: context)?.level, level)
                    XCTAssertEqual(EchoLevel.selection(for: context)?.patternIndex, index)
                    XCTAssertEqual(restored.melodyContext, context)
                    XCTAssertEqual(restored.melodyRating, archived.melodyRating)
                    XCTAssertEqual(restored.melodyRating?.version, 1)
                    XCTAssertEqual(restored.title, "Listen & Echo · \(level.title)")
                    XCTAssertEqual(restored.starCount, 3)
                    XCTAssertEqual(restored.melodyRating?.echoFeedback,
                                   "All three goals reached. Try a fresh pattern.")
                }
            }
        }
    }

    func testHistoricalThreeStarTakesCannotCreditCurrentVersionProgress() throws {
        let old = try (0..<3).map { index in
            let context = replacing(try EchoLevel.twoNotes.context(patternIndex: index, register: .lowVoice),
                                    gradingVersion: 1)
            return try session(at: index, context: context, version: 1)
        }
        var ledger = EchoProgressLedger()
        XCTAssertTrue(old.allSatisfy { $0.starCount == 3 })
        XCTAssertFalse(ledger.update(from: old))
        XCTAssertTrue(ledger.completedKeys.isEmpty)
        XCTAssertEqual(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: old).successfulAttempts, 0)

        var mixed = old + (try (3..<5).map { try session(at: $0, pattern: $0) })
        ledger.update(from: mixed)
        XCTAssertTrue(ledger.completedKeys.isEmpty, "A pass is kept, but it is not gold")
        let unfinished = ledger.progress(for: .twoNotes, register: .lowVoice, sessions: mixed)
        XCTAssertEqual(unfinished.successfulAttempts, 2)
        XCTAssertFalse(unfinished.completed)
        mixed.append(try session(at: 5, pattern: 5))
        XCTAssertTrue(ledger.update(from: mixed))
        XCTAssertTrue(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: mixed).completed)
    }

    func testHistoricalCompletionKeySurvivesReloadAndCurrentCompletionWithoutCreditingIt() throws {
        // Reconstruct the v1 catalogue identity stored by the previous release.
        let oldContexts = try (0..<EchoLevel.twoNotes.patternCount).map {
            replacing(try EchoLevel.twoNotes.context(patternIndex: $0, register: .lowVoice), gradingVersion: 1)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let oldKey = SHA256.hash(data: try encoder.encode(oldContexts))
            .map { String(format: "%02x", $0) }.joined()
        let saved = try encoder.encode(EchoProgressLedger(completedKeys: [oldKey]))
        var ledger = try JSONDecoder().decode(EchoProgressLedger.self, from: saved)
        XCTAssertEqual(ledger.completedKeys, [oldKey])
        XCTAssertFalse(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: []).completed)
        XCTAssertFalse(ledger.update(from: []))
        XCTAssertEqual(ledger.completedKeys, [oldKey])

        let current = try (0..<3).map { try session(at: $0, pattern: $0) }
        XCTAssertTrue(ledger.update(from: current))
        XCTAssertTrue(ledger.completedKeys.contains(oldKey))
        XCTAssertEqual(ledger.completedKeys.count, 2, "The current grade must earn a separate achievement")
        let restored = try JSONDecoder().decode(EchoProgressLedger.self, from: encoder.encode(ledger))
        XCTAssertEqual(restored.completedKeys, ledger.completedKeys)
        XCTAssertTrue(restored.progress(for: .twoNotes, register: .lowVoice, sessions: []).completed)
    }

    func testThreeSuccessesAmongFiveDifferentPatternsCompleteOnlyTheSelectedLevelAndVoice() throws {
        let sessions = try [true, false, true, false, true].enumerated().map {
            try session(at: $0.offset, pattern: $0.offset, success: $0.element)
        }
        var ledger = EchoProgressLedger()
        XCTAssertTrue(ledger.update(from: sessions))
        XCTAssertFalse(ledger.update(from: sessions), "Replaying the same history must be idempotent")
        let progress = ledger.progress(for: .twoNotes, register: .lowVoice, sessions: sessions)
        XCTAssertTrue(progress.completed)
        XCTAssertEqual(progress.successfulAttempts, 3)
        XCTAssertFalse(ledger.progress(for: .twoNotes, register: .higherVoice, sessions: sessions).completed)
        XCTAssertFalse(ledger.progress(for: .threeNotes, register: .lowVoice, sessions: sessions).completed)
        XCTAssertEqual(ledger.progress(for: .twoNotes, register: .cello, sessions: sessions).successfulAttempts, 0)
    }

    func testUnratedWrongVersionForeignAndFoundationHistoryCannotAdvanceEcho() throws {
        let canonical = try EchoLevel.twoNotes.context(patternIndex: 2, register: .lowVoice)
        var history = try [session(at: 0, pattern: 0), session(at: 1, pattern: 1)]
        history += try (2..<9).map { try session(at: $0, pattern: $0 % 6, status: .unclear) }
        history += try [
            session(at: 10, context: canonical, version: 99),
            session(at: 11, context: replacing(canonical, gradingVersion: 99), version: 99),
            session(at: 12, context: replacing(canonical, tuning: 441)),
            session(at: 13, context: replacing(canonical, tempo: 72)),
            session(at: 14, context: canonical, exercise: .steadyHum),
            session(at: 15, context: canonical, foundationRating: true),
            session(at: 16, context: .hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                gradingVersion: MelodyRating.currentVersion)),
            session(at: 17, context: .odeToJoy(register: .lowVoice, section: .phrase1,
                                             gradingVersion: MelodyRating.currentVersion)),
            session(at: 18, level: .threeNotes, pattern: 0),
            session(at: 19, register: .higherVoice, pattern: 0)
        ]
        var ledger = EchoProgressLedger()
        ledger.update(from: history)
        XCTAssertTrue(ledger.completedKeys.isEmpty, "A pass is kept, but it is not gold")
        XCTAssertEqual(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: history).successfulAttempts, 2)
        XCTAssertFalse(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: history).completed)
        XCTAssertFalse(MelodyProgressLedger().progress(for: try .hotCrossBuns(register: .lowVoice,
            section: .phrase1, gradingVersion: MelodyRating.currentVersion), sessions: history).completed)
        XCTAssertFalse(PracticeProgressLedger().progress(for: .steadyHum,
            targetFrequency: HummingExample.frequency, sessions: history).completed)
        history.append(try session(at: 20, pattern: 2))
        XCTAssertTrue(ledger.update(from: history))
        XCTAssertTrue(ledger.progress(for: .twoNotes, register: .lowVoice, sessions: history).completed)
    }

    func testSuccessesOutsideTheLastFiveRatedRoundsDoNotAccumulate() throws {
        let history = try [true, true, false, false, false, false, false, true].enumerated().map {
            try session(at: $0.offset, pattern: $0.offset % 6, success: $0.element)
        }
        var ledger = EchoProgressLedger()
        ledger.update(from: history)
        XCTAssertTrue(ledger.completedKeys.isEmpty, "A pass is kept, but it is not gold")
        let progress = ledger.progress(for: .twoNotes, register: .lowVoice, sessions: history)
        XCTAssertFalse(progress.completed)
        XCTAssertEqual(progress.successfulAttempts, 1)
    }

    func testEarnedCompletionSurvivesLaterMissesReloadAndDeletedRecordings() throws {
        let successes = try (0..<3).map { try session(at: $0, pattern: $0) }
        let misses = try (3..<12).map { try session(at: $0, pattern: $0 % 6, success: false) }
        var ledger = EchoProgressLedger()
        XCTAssertTrue(ledger.update(from: successes + misses))
        let restored = try JSONDecoder().decode(EchoProgressLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored.schemaVersion, 1)
        XCTAssertEqual(restored.completedKeys.count, 1)
        XCTAssertEqual(restored.completedKeys.first?.count, 64)
        for remaining in [misses, []] {
            XCTAssertTrue(restored.progress(for: .twoNotes, register: .lowVoice, sessions: remaining).completed)
            XCTAssertEqual(restored.progress(for: .twoNotes, register: .lowVoice, sessions: remaining).successfulAttempts, 3)
        }
        XCTAssertFalse(restored.progress(for: .twoNotes, register: .higherVoice, sessions: []).completed)
        XCTAssertFalse(restored.progress(for: .threeNotes, register: .lowVoice, sessions: []).completed)
    }

    private func session(at index: Int, level: EchoLevel = .twoNotes, register: MelodyRegister = .lowVoice,
                         pattern: Int = 0, success: Bool = true, status: MelodyRating.Status = .rated,
                         context override: MelodyPracticeContext? = nil, version: Int = MelodyRating.currentVersion,
                         exercise: Exercise = .listen, foundationRating: Bool = false) throws -> PracticeSession {
        let context = try override ?? level.context(patternIndex: pattern, register: register)
        return PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
            exercise: exercise, duration: context.duration, notes: "", pitchSamples: [], videoFilename: "echo.mov",
            rating: foundationRating ? PracticeRating(targetFrequency: HummingExample.frequency,
                status: .rated, match: true, steady: true, hold: true) : nil,
            melodyContext: context, melodyRating: MelodyRating(version: version, status: status,
                notes: success, timing: true, clarity: true))
    }

    private func replacing(_ context: MelodyPracticeContext, pieceID: String? = nil,
                           scoreVersion: Int? = nil, register: MelodyRegister? = nil,
                           key: String? = nil, tuning: Double? = nil, tempo: Int? = nil,
                           section: MelodySection? = nil, events: [MelodyEvent]? = nil,
                           duration: Double? = nil, gradingVersion: Int? = nil) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: pieceID ?? context.pieceID, scoreVersion: scoreVersion ?? context.scoreVersion,
            register: register ?? context.register, referenceKey: key ?? context.referenceKey,
            tuningA4Hz: tuning ?? context.tuningA4Hz, tempoBPM: tempo ?? context.tempoBPM,
            section: section ?? context.section, expectedEvents: events ?? context.expectedEvents,
            durationBeats: duration ?? context.durationBeats, gradingVersion: gradingVersion ?? context.gradingVersion)
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }
}
