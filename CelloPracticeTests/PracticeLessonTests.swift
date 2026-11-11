import Foundation
import XCTest
@testable import Cello

final class PracticeLessonTests: XCTestCase {
    func testLessonBookPreservesExistingIDsAndActivities() {
        XCTAssertEqual(PracticeLesson.allCases.map(\.id), ["steadyHum", "matchHum", "pulse", "twoTaps", "mixedRhythm"])
        XCTAssertEqual(PracticeLesson.allCases.map(\.activity),
                       [.recording(.steadyHum), .recording(.matchHum), .rhythm(.pulse), .rhythm(.twoTaps), .rhythm(.mixedRhythm)])
        XCTAssertEqual(PracticeSection.allCases, [.humming, .cello])
    }

    func testEarnedCompletionSurvivesDeletedHistory() {
        var ledger = PracticeProgressLedger()
        XCTAssertFalse(ledger.progress(for: .matchHum, targetFrequency: HummingExample.frequency,
                                       sessions: []).completed)
        let successes = (0..<3).map { session(at: $0, stars: 3, exercise: .matchHum) }
        XCTAssertTrue(ledger.update(from: successes))
        for history in [successes, []] {
            XCTAssertTrue(ledger.progress(for: .matchHum, targetFrequency: HummingExample.frequency,
                                          sessions: history).completed)
        }
    }

    func testOnlyTheFirstLevelLessonsHavePrimersAndEachHasSomethingToHearOrFeel() {
        let withPrimers = PracticeLesson.allCases.filter { $0.primer != nil }
        XCTAssertEqual(withPrimers, [.steadyHum, .matchHum, .pulse, .twoTaps])
        XCTAssertEqual(withPrimers.map(PathLesson.lesson), Array(Level.path[0].lessons.prefix(4)),
                       "Each new idea in Level 1 is explained before the lesson that needs it")
        XCTAssertEqual(PracticeLesson.steadyHum.primer?.demo, .hum)
        XCTAssertEqual(PracticeLesson.matchHum.primer?.demo, .twoNotes)
        guard case .beats(let beat)? = PracticeLesson.pulse.primer?.demo,
              case .beats(let twoTaps)? = PracticeLesson.twoTaps.primer?.demo else { return XCTFail("Rhythm primers count beats") }
        XCTAssertEqual(beat.map(\.label), ["1", "2", "3", "4"])
        XCTAssertEqual(beat.map(\.seconds).reduce(0, +), 4)
        XCTAssertEqual(twoTaps.map(\.label), ["1", "&", "2", "&", "3", "&", "4", "&"])
        XCTAssertEqual(twoTaps.filter(\.onBeat).count, 4, "Only the numbers vibrate")
        XCTAssertEqual(twoTaps.map(\.seconds).reduce(0, +), 4, "The beat stays one second long")
    }

    func testNoLevelOneLessonUsesATermBeforeAPrimerHasExplainedIt() {
        var explained = ""
        for step in Level.path[0].lessons {
            guard case .lesson(let lesson) = step else { continue }
            explained += " " + (lesson.primer?.paragraphs.joined(separator: " ").lowercased() ?? "")
            let copy = ([lesson.purpose, lesson.practicePrompt(.voice), lesson.practicePrompt(.cello)] + lesson.instructions
                        + lesson.goals.flatMap { [$0.title, $0.detail] }).joined(separator: " ").lowercased()
            for term in ["pitch", "beat", "cents", "register", "bpm", "pulse"] where copy.contains(term) {
                XCTAssertTrue(explained.contains(term), "\(lesson.title) uses “\(term)” before a primer explains it")
            }
        }
    }

    func testBestAndLatestUseOnlyScoresForTheExactLessonReferenceAndVersion() {
        let target = HummingExample.frequency
        let best = session(at: 2, stars: 2)
        let latest = session(at: 3, stars: 1)
        let excluded = [
            session(at: 4, stars: 3, exercise: .matchHum),
            session(at: 5, stars: 3, target: target * 2),
            session(at: 6, stars: 3, version: PracticeRating.currentVersion + 1),
            session(at: 7, stars: 3, ratingTarget: target * 2),
            session(at: 8, stars: 3, status: .unclear)
        ]
        let result = LessonScoreSummary(exercise: .steadyHum, targetFrequency: target,
                                        sessions: [latest, best] + excluded, completed: false)
        XCTAssertTrue(result.hasAttempts)
        XCTAssertEqual(result.bestStars, 2)
        XCTAssertEqual(result.latestStars, 1)
    }

    func testEarnedCompletionProvesBestButDoesNotInventLatestAfterDeletion() {
        let result = LessonScoreSummary(exercise: .steadyHum, targetFrequency: HummingExample.frequency,
                                        sessions: [], completed: true)
        XCTAssertTrue(result.hasAttempts)
        XCTAssertEqual(result.bestStars, 3)
        XCTAssertNil(result.latestStars)
    }

    @MainActor
    func testDeletedPassingTakeKeepsTheFoundationScoreUsedByThePathTodayAndDetail() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PassedLesson-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions")
        let steady = session(at: 0, stars: 2)
        let match = session(at: 1, stars: 2, exercise: .matchHum)
        // Archived-rating fixtures verify state and deletion, not acoustic grading.
        for take in [steady, match] {
            let folder = directory.appendingPathComponent(take.id.uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try SessionStore.writeMetadata(take, to: folder)
            try Data("archived take".utf8).write(to: folder.appendingPathComponent(take.videoFilename))
        }

        let store = SessionStore(directory: directory)
        let rhythms = RhythmStores(directory: root)
        let before = LessonState(lesson: .matchHum, store: store, rhythmStores: rhythms)
        XCTAssertEqual(before.bestStars, 2)
        XCTAssertEqual(before.latestStars, 2)
        XCTAssertTrue(before.step.passed)
        XCTAssertFalse(before.step.gold)
        store.delete(match)
        XCTAssertNil(store.errorMessage)

        let reloaded = SessionStore(directory: directory)
        XCTAssertNil(reloaded.errorMessage)
        XCTAssertEqual(reloaded.sessions.map(\.id), [steady.id])
        let kept = LessonState(lesson: .matchHum, store: reloaded, rhythmStores: rhythms)
        XCTAssertTrue(kept.step.passed)
        XCTAssertFalse(kept.step.gold)
        XCTAssertEqual(kept.bestStars, 2, "The path row and detail retain the score proved by the pass")
        XCTAssertNil(kept.latestStars, "Deleting its take must not invent a latest saved score")
        XCTAssertEqual(kept.step.bestStars, 2)

        let states = [PathLesson.lesson(.steadyHum): LessonState(lesson: .steadyHum, store: reloaded, rhythmStores: rhythms),
                      .lesson(.matchHum): kept]
        let today = Level.today(isPassed: { states[$0]?.step.passed ?? false },
                                stars: { states[$0]?.bestStars ?? 0 })
        XCTAssertEqual(today, [.lesson(.pulse), .lesson(.steadyHum), .lesson(.matchHum)],
                       "Both passed lessons still rank as two stars, so their path order breaks the tie")
    }

    func testUnratedHistoryDoesNotBecomeAZeroStarScore() {
        let target = HummingExample.frequency
        let legacy = PracticeSession(id: UUID(), createdAt: Date(), exercise: .steadyHum,
            duration: 3, notes: "", pitchSamples: [], videoFilename: "legacy.mov",
            tuningTargetFrequency: target)
        let result = LessonScoreSummary(exercise: .steadyHum, targetFrequency: target,
            sessions: [legacy, session(at: 1, stars: 0, status: .insufficientSound)], completed: false)
        XCTAssertTrue(result.hasAttempts)
        XCTAssertNil(result.bestStars)
        XCTAssertNil(result.latestStars)

        let neverStarted = LessonScoreSummary(exercise: .openC,
            targetFrequency: Exercise.openC.targetFrequency!, sessions: [legacy], completed: false)
        XCTAssertFalse(neverStarted.hasAttempts)
        XCTAssertNil(neverStarted.bestStars)
        XCTAssertNil(neverStarted.latestStars)
    }

    func testARealZeroStarRatingRemainsARealScore() {
        let result = LessonScoreSummary(exercise: .steadyHum, targetFrequency: HummingExample.frequency,
                                        sessions: [session(at: 1, stars: 0)], completed: false)
        XCTAssertEqual(result.bestStars, 0)
        XCTAssertEqual(result.latestStars, 0)
    }

    private func session(at index: Int, stars: Int, exercise: Exercise = .steadyHum,
                         target: Double = HummingExample.frequency,
                         version: Int = PracticeRating.currentVersion,
                         ratingTarget: Double? = nil,
                         status: PracticeRating.Status = .rated) -> PracticeSession {
        PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
            exercise: exercise, duration: 3, notes: "", pitchSamples: [],
            videoFilename: "recording.mov", tuningTargetFrequency: target,
            rating: PracticeRating(version: version, targetFrequency: ratingTarget ?? target,
                status: status, match: stars >= 1, steady: stars >= 2, hold: stars >= 3))
    }
}
