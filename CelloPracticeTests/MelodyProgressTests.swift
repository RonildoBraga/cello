import Foundation
import XCTest
@testable import Cello

final class MelodyProgressTests: XCTestCase {
    func testThreeSuccessesAmongFiveRatedAttemptsEarnCompletion() throws {
        let context = try context()
        let rated = [true, false, true, false, true].enumerated().map {
            session(at: $0.offset, context: context, success: $0.element)
        }
        let unclear = (5..<12).map { session(at: $0, context: context, success: false, status: .unclear) }
        var ledger = MelodyProgressLedger()
        XCTAssertTrue(ledger.update(from: rated + unclear))
        let progress = ledger.progress(for: context, sessions: rated + unclear)
        XCTAssertTrue(progress.completed)
        XCTAssertEqual(progress.successfulAttempts, 3)
    }

    func testSuccessesOutsideTheLastFiveDoNotAccumulate() throws {
        let context = try context()
        let sessions = [true, true, false, false, false, false, false, true].enumerated().map {
            session(at: $0.offset, context: context, success: $0.element)
        }
        var ledger = MelodyProgressLedger()
        XCTAssertFalse(ledger.update(from: sessions))
        XCTAssertEqual(ledger.progress(for: context, sessions: sessions).successfulAttempts, 1)
        XCTAssertFalse(ledger.progress(for: context, sessions: sessions).completed)
    }

    func testEveryFrozenReferenceDimensionKeepsItsOwnProgress() throws {
        let original = try context()
        let different: [MelodyPracticeContext] = [
            try context(section: .phrase2), try context(register: .higherVoice),
            try context(tempo: 72), try context(pieceID: "anotherPiece"),
            try context(scoreVersion: 2), try context(referenceKey: "Other reference"),
            try context(tuning: 441), try context(pitchShift: 1)
        ]
        var sessions = (0..<2).map { session(at: $0, context: original, success: true) }
        for (offset, context) in different.enumerated() {
            sessions += (0..<3).map { session(at: 10 + offset * 3 + $0, context: context, success: true) }
        }
        var ledger = MelodyProgressLedger()
        XCTAssertTrue(ledger.update(from: sessions))
        XCTAssertEqual(ledger.progress(for: original, sessions: sessions).successfulAttempts, 2)
        XCTAssertFalse(ledger.progress(for: original, sessions: sessions).completed)
        for context in different { XCTAssertTrue(ledger.progress(for: context, sessions: sessions).completed) }
    }

    func testUnknownScoringVersionsUnratedAndFoundationHistoryCannotCompleteMelody() throws {
        let current = try context()
        let otherVersion = try context(gradingVersion: MelodyRating.currentVersion + 1)
        let ungraded = try context(gradingVersion: nil)
        var sessions = (0..<2).map { session(at: $0, context: current, success: true) }
        sessions += (2..<5).map { session(at: $0, context: otherVersion, success: true,
                                         version: MelodyRating.currentVersion + 1) }
        sessions += (5..<8).map { session(at: $0, context: ungraded, success: true) }
        sessions += (8..<11).map { session(at: $0, context: current, success: true, version: 99) }
        sessions += (11..<14).map { session(at: $0, context: current, success: true, status: .insufficientSound) }
        sessions += (14..<17).map { index in
            PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
                exercise: .steadyHum, duration: 3, notes: "", pitchSamples: [], videoFilename: "recording.mov",
                tuningTargetFrequency: HummingExample.frequency,
                rating: PracticeRating(targetFrequency: HummingExample.frequency, status: .rated,
                                       match: true, steady: true, hold: true))
        }
        var ledger = MelodyProgressLedger()
        XCTAssertFalse(ledger.update(from: sessions))
        XCTAssertEqual(ledger.progress(for: current, sessions: sessions).successfulAttempts, 2)
        XCTAssertFalse(ledger.progress(for: otherVersion, sessions: sessions).completed)
        XCTAssertFalse(ledger.progress(for: ungraded, sessions: sessions).completed)
        let foundation = PracticeProgressLedger().progress(for: .steadyHum,
            targetFrequency: HummingExample.frequency, sessions: sessions)
        XCTAssertTrue(foundation.completed, "Real foundation achievements keep their own eligibility")
    }

    func testCompletionSurvivesLaterMissesReloadAndDeletedHistory() throws {
        let context = try context()
        let successes = (0..<3).map { session(at: $0, context: context, success: true) }
        let later = (3..<10).map { session(at: $0, context: context, success: false) }
        var ledger = MelodyProgressLedger()
        XCTAssertTrue(ledger.update(from: successes + later))
        let restored = try JSONDecoder().decode(MelodyProgressLedger.self, from: JSONEncoder().encode(ledger))
        for history in [later, []] {
            XCTAssertTrue(restored.progress(for: context, sessions: history).completed)
            XCTAssertEqual(restored.progress(for: context, sessions: history).successfulAttempts, 3)
        }
        XCTAssertFalse(restored.progress(for: try self.context(section: .whole), sessions: []).completed)
    }

    private func context(register: MelodyRegister = .lowVoice, section: MelodySection = .phrase1,
                         tempo: Int = 60, pieceID: String = "hotCrossBuns", scoreVersion: Int = 1,
                         referenceKey: String? = nil, tuning: Double = 440, pitchShift: Int = 0,
                         gradingVersion: Int? = MelodyRating.currentVersion) throws -> MelodyPracticeContext {
        let base = try MelodyPracticeContext.hotCrossBuns(register: register, section: section, tempoBPM: tempo)
        return MelodyPracticeContext(pieceID: pieceID, scoreVersion: scoreVersion, register: register,
            referenceKey: referenceKey ?? base.referenceKey, tuningA4Hz: tuning, tempoBPM: tempo,
            section: section, expectedEvents: base.expectedEvents.map {
                MelodyEvent(onsetBeat: $0.onsetBeat, durationBeats: $0.durationBeats,
                            midiNote: $0.midiNote.map { $0 + pitchShift })
            }, durationBeats: base.durationBeats, gradingVersion: gradingVersion)
    }

    private func session(at index: Int, context: MelodyPracticeContext, success: Bool,
                         status: MelodyRating.Status = .rated,
                         version: Int = MelodyRating.currentVersion) -> PracticeSession {
        PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
            exercise: .listen, duration: context.duration, notes: "", pitchSamples: [],
            videoFilename: "recording.mov", melodyContext: context,
            melodyRating: MelodyRating(version: version, status: status, notes: success,
                                       timing: true, clarity: true))
    }
}
