import Foundation
import XCTest
@testable import Cello

final class PracticeLessonTests: XCTestCase {
    func testLessonBookSeparatesAreasAndPreservesExistingNumbersAndIDs() {
        let humming = PracticeLesson.lessons(in: .humming)
        XCTAssertEqual(humming.map(\.number), [1, 2])
        XCTAssertEqual(humming.map(\.id), ["steadyHum", "matchHum"])
        XCTAssertTrue(humming.allSatisfy { $0.area == .humming })
        XCTAssertEqual(humming.map(\.activity), [.recording(.steadyHum), .recording(.matchHum)])

        let rhythm = PracticeLesson.lessons(in: .rhythm)
        XCTAssertEqual(rhythm.map(\.number), [3, 4, 5])
        XCTAssertEqual(rhythm.map(\.id), ["pulse", "twoTaps", "mixedRhythm"])
        XCTAssertTrue(rhythm.allSatisfy { $0.area == .rhythm })
        XCTAssertEqual(rhythm.map(\.activity), [.rhythm(.pulse), .rhythm(.twoTaps), .rhythm(.mixedRhythm)])

        let cello = PracticeLesson.lessons(in: .cello)
        XCTAssertEqual(cello.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(cello.map(\.id), ["openC", "openG", "openD", "openA"])
        XCTAssertEqual(cello.map(\.activity), [.recording(.openC), .recording(.openG),
                                                 .recording(.openD), .recording(.openA)])
        XCTAssertTrue(cello.allSatisfy { $0.area == .cello })
        XCTAssertEqual(humming.count + rhythm.count + cello.count, PracticeLesson.allCases.count)
    }

    func testOriginalFoundationRecommendationsContinueAcrossAreasAndStopAtEachPathEnd() {
        let transitions: [(PracticeLesson, PracticeLesson)] = [
            (.steadyHum, .matchHum), (.matchHum, .pulse), (.pulse, .twoTaps), (.twoTaps, .mixedRhythm),
            (.openC, .openG), (.openG, .openD), (.openD, .openA)
        ]
        for (current, expected) in transitions {
            XCTAssertEqual(current.next, expected)
            XCTAssertEqual(expected.number, current.number + 1)
        }
        XCTAssertEqual(PracticeLesson.matchHum.area, .humming)
        XCTAssertEqual(PracticeLesson.matchHum.next?.area, .rhythm)
        XCTAssertNil(PracticeLesson.mixedRhythm.next)
        XCTAssertNil(PracticeLesson.openA.next)
    }

    func testNextLessonStaysAvailableBeforeCompletionAndAfterDeletedHistory() {
        let lesson = PracticeLesson.matchHum
        var ledger = PracticeProgressLedger()
        XCTAssertFalse(ledger.progress(for: .matchHum, targetFrequency: HummingExample.frequency,
                                       sessions: []).completed)
        XCTAssertEqual(lesson.next, .pulse)
        let successes = (0..<3).map { session(at: $0, stars: 3, exercise: .matchHum) }
        XCTAssertTrue(ledger.update(from: successes))
        for history in [successes, []] {
            XCTAssertTrue(ledger.progress(for: .matchHum, targetFrequency: HummingExample.frequency,
                                          sessions: history).completed)
            XCTAssertEqual(lesson.next, .pulse)
        }
    }

    func testSelectionRemembersCompleteLessonsIndependentlyForEachArea() {
        var selection = PracticeSelection()
        XCTAssertEqual(selection.area, .humming)
        XCTAssertEqual(selection.lesson, .steadyHum)
        selection.area = .rhythm
        XCTAssertEqual(selection.lesson, .pulse)
        selection.area = .cello
        XCTAssertEqual(selection.lesson, .openG)
        selection.select(.openD)
        selection.select(.twoTaps)
        XCTAssertEqual(selection.area, .rhythm)
        selection.area = .humming
        XCTAssertEqual(selection.lesson, .steadyHum)
        selection.select(.matchHum)
        selection.area = .rhythm
        XCTAssertEqual(selection.lesson, .twoTaps)
        selection.area = .cello
        XCTAssertEqual(selection.lesson, .openD)
        selection.select(.pulse)
        XCTAssertEqual(selection.area, .rhythm, "Starting a library lesson should select its own area atomically")
        XCTAssertEqual(selection.lesson, .pulse)
        selection.area = .humming
        XCTAssertEqual(selection.lesson, .matchHum)
        selection.area = .cello
        XCTAssertEqual(selection.lesson, .openD)
    }

    func testEveryLessonRoutesToItsOwnAreaAndTypedActivityWithoutAddingRecordingTargets() {
        var selection = PracticeSelection()
        XCTAssertEqual(LearningArea.allCases, [.humming, .rhythm, .cello])
        XCTAssertEqual(PracticeSection.allCases, [.humming, .cello])
        for area in LearningArea.allCases {
            XCTAssertEqual(area.defaultLesson.area, area)
        }
        for lesson in PracticeLesson.allCases {
            selection.select(lesson)
            XCTAssertEqual(selection.lesson, lesson)
            XCTAssertEqual(selection.area, lesson.area)
            switch lesson.activity {
            case .recording(let exercise):
                XCTAssertNotNil(exercise.section)
                XCTAssertEqual(lesson.area, exercise.section == .humming ? .humming : .cello)
            case .rhythm: XCTAssertEqual(lesson.area, .rhythm)
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
