import Foundation
import XCTest
@testable import Cello

final class PracticeProgressTests: XCTestCase {
    func testThreeSuccessesAmongFiveEligibleAttemptsEarnCompletion() {
        let target = HummingExample.frequency
        let sessions = [true, false, true, false, true].enumerated().map {
            session(at: $0.offset, success: $0.element)
        }
        let unclear = (5..<10).map { session(at: $0, success: false, status: .unclear) }
        var ledger = PracticeProgressLedger()
        XCTAssertTrue(ledger.update(from: sessions + unclear))
        let progress = ledger.progress(for: .steadyHum, targetFrequency: target,
                                       sessions: sessions + unclear)
        XCTAssertTrue(progress.completed)
        XCTAssertEqual(progress.successfulAttempts, 3)
        XCTAssertEqual(progress.requiredAttempts, 3)
    }

    func testOldSuccessesOutsideTheRecentFiveDoNotAccumulateIndefinitely() {
        let pattern = [true, true, false, false, false, false, false, true]
        let sessions = pattern.enumerated().map { session(at: $0.offset, success: $0.element) }
        var ledger = PracticeProgressLedger()
        ledger.update(from: sessions)
        XCTAssertTrue(ledger.completedKeys.isEmpty, "A pass is kept, but it is not gold")
        let progress = ledger.progress(for: .steadyHum, targetFrequency: HummingExample.frequency,
                                       sessions: sessions)
        XCTAssertEqual(progress.successfulAttempts, 1)
        XCTAssertFalse(progress.completed)
    }

    func testExercisesTargetsVersionsAndUnratedHistoryStaySeparate() {
        let target = HummingExample.frequency
        let current = [session(at: 0, success: true), session(at: 1, success: true)]
        let otherExercise = (2..<5).map { session(at: $0, success: true, exercise: .matchHum) }
        let otherTarget = (5..<8).map { session(at: $0, success: true, target: 103.82617439498628) }
        let otherVersion = (8..<11).map { session(at: $0, success: true, version: PracticeRating.currentVersion + 1) }
        let cello = (11..<14).map { session(at: $0, success: true, exercise: .openG, target: 97.99885899543733) }
        let unscored = (14..<19).map { session(at: $0, success: true, status: .insufficientSound) }
        let legacy = PracticeSession(id: UUID(), createdAt: Date(), exercise: .steadyHum,
            duration: 3, notes: "", pitchSamples: [], videoFilename: "recording.mov",
            tuningTargetFrequency: target)
        let all = current + otherExercise + otherTarget + otherVersion + cello + unscored + [legacy]
        var ledger = PracticeProgressLedger()
        ledger.update(from: all)
        let progress = ledger.progress(for: .steadyHum, targetFrequency: target, sessions: all)
        XCTAssertEqual(progress.successfulAttempts, 2)
        XCTAssertFalse(progress.completed)
        XCTAssertTrue(ledger.progress(for: .matchHum, targetFrequency: target, sessions: all).completed)
        XCTAssertTrue(ledger.progress(for: .openG, targetFrequency: 97.99885899543733, sessions: all).completed)
        XCTAssertFalse(ledger.progress(for: .listen, targetFrequency: target, sessions: all).completed)
    }

    func testCompletionSurvivesLaterDifficultTakesAndDeletedHistory() throws {
        let successes = (0..<3).map { session(at: $0, success: true) }
        let later = (3..<10).map { session(at: $0, success: false) }
        var ledger = PracticeProgressLedger()
        // Reconstruction sees the earlier successful window even after later misses.
        XCTAssertTrue(ledger.update(from: successes + later))
        let data = try JSONEncoder().encode(ledger)
        let restored = try JSONDecoder().decode(PracticeProgressLedger.self, from: data)
        for history in [later, []] {
            let result = restored.progress(for: .steadyHum, targetFrequency: HummingExample.frequency,
                                           sessions: history)
            XCTAssertTrue(result.completed)
            XCTAssertEqual(result.successfulAttempts, 3)
        }
    }

    func testAPassSurvivesDeletedHistoryAndOldFilesStillRead() throws {
        var ledger = PracticeProgressLedger()
        // Two of three stars: a pass, not gold.
        XCTAssertTrue(ledger.update(from: [session(at: 0, success: false)]))
        XCTAssertFalse(ledger.update(from: [session(at: 0, success: false)]), "Nothing new to save")
        let restored = try JSONDecoder().decode(PracticeProgressLedger.self, from: JSONEncoder().encode(ledger))
        let kept = restored.progress(for: .steadyHum, targetFrequency: HummingExample.frequency, sessions: [])
        XCTAssertTrue(kept.passed)
        XCTAssertFalse(kept.completed)
        XCTAssertEqual(kept.bestStars, 2)
        XCTAssertEqual(kept.successfulAttempts, 0)

        // A file written before passes were kept has no such field.
        let old = try JSONDecoder().decode(PracticeProgressLedger.self,
                                           from: Data(#"{"schemaVersion":1,"completedKeys":[]}"#.utf8))
        XCTAssertNil(old.passedKeys)
        XCTAssertFalse(old.progress(for: .steadyHum, targetFrequency: HummingExample.frequency, sessions: []).passed)
    }

    func testTheTakesAreReadIntoStarsPerAchievementNewestFirst() {
        // success: three stars; otherwise two. Unrated and other-version takes count for nothing.
        let takes = [session(at: 0, success: true), session(at: 2, success: false), session(at: 1, success: true),
                     session(at: 3, success: true, exercise: .matchHum),
                     session(at: 4, success: true, status: .unclear),
                     session(at: 5, success: true, version: PracticeRating.currentVersion + 1)]
        let stars = PracticeProgressLedger.stars(in: takes)
        XCTAssertEqual(stars.count, 2, "One entry for each achievement that has a counted take")
        XCTAssertEqual(Set(stars.values), [[2, 3, 3], [3]])

        // Progress read from the stars is the progress read from the takes.
        var ledger = PracticeProgressLedger()
        ledger.update(from: stars)
        let target = HummingExample.frequency
        for exercise in [Exercise.steadyHum, .matchHum, .openG] {
            let key = PracticeProgressLedger.key(exercise: exercise, targetFrequency: target)
            XCTAssertEqual(ledger.progress(forKey: key, stars: stars),
                           ledger.progress(for: exercise, targetFrequency: target, sessions: takes))
        }
        XCTAssertEqual(ledger.progress(for: .steadyHum, targetFrequency: target, sessions: takes).successfulAttempts, 2)
        XCTAssertEqual(ledger.passedKeys?.count, 2)
    }

    func testRatingMustAgreeWithTheSavedReference() {
        let target = HummingExample.frequency
        let mismatches = (0..<3).map { index in
            PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
                exercise: .steadyHum, duration: 3, notes: "", pitchSamples: [],
                videoFilename: "recording.mov", tuningTargetFrequency: target,
                rating: rating(target: target * 2, success: true))
        }
        var ledger = PracticeProgressLedger()
        XCTAssertFalse(ledger.update(from: mismatches))
        XCTAssertEqual(ledger.progress(for: .steadyHum, targetFrequency: target,
                                       sessions: mismatches).successfulAttempts, 0)
    }

    private func session(at index: Int, success: Bool, exercise: Exercise = .steadyHum,
                         target: Double = HummingExample.frequency,
                         status: PracticeRating.Status = .rated,
                         version: Int = PracticeRating.currentVersion) -> PracticeSession {
        PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
            exercise: exercise, duration: 3, notes: "", pitchSamples: [],
            videoFilename: "recording.mov", tuningTargetFrequency: target,
            rating: rating(target: target, success: success, status: status, version: version))
    }

    private func rating(target: Double, success: Bool,
                        status: PracticeRating.Status = .rated,
                        version: Int = PracticeRating.currentVersion) -> PracticeRating {
        PracticeRating(version: version, targetFrequency: target, status: status,
            match: success, steady: true, hold: true, voicedDuration: 2.8, longestHold: 2.8,
            nearTargetFraction: success ? 0.9 : 0.3, settledSpreadCents: 20)
    }
}
