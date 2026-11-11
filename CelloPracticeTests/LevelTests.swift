import XCTest
@testable import Cello

final class LevelTests: XCTestCase {
    func testPathIsFirstSoundsThenOneLevelPerMelodyThenTheCello() {
        XCTAssertEqual(Level.path.map(\.id), ["firstSounds", "hotCrossBuns", "odeToJoy", "cello"])
        XCTAssertEqual(Level.path.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(Level.path[0].lessons, [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse),
                                             .lesson(.twoTaps), .lesson(.mixedRhythm), .echo])
        XCTAssertEqual(Level.path[3].lessons, [.celloIntroduction, .lesson(.openC), .lesson(.openG),
                                             .lesson(.openD), .lesson(.openA)])
    }

    func testEveryMelodyLevelHasTheSameLessonsInTheSameOrder() {
        XCTAssertEqual(Level.path.count, MelodyPiece.allCases.count + 2)
        for (level, piece) in zip(Level.path.dropFirst(), MelodyPiece.allCases) {
            XCTAssertEqual(level.title, piece.title)
            XCTAssertEqual(level.lessons, [.listen(piece), .tap(piece), .meetNotes(piece), .hum(piece), .wholeMelody(piece)])
            XCTAssertEqual(level.lessons.map(\.title), ["Listen", "Tap it", "Meet the notes", "Hum it", "Whole melody"])
        }
    }

    func testEveryLessonBelongsToExactlyOneLevel() {
        let all = Level.path.flatMap(\.lessons)
        let foundation = all.compactMap { item -> PracticeLesson? in
            if case .lesson(let lesson) = item { return lesson }
            return nil
        }
        XCTAssertEqual(foundation.count, PracticeLesson.allCases.count)
        XCTAssertEqual(Set(foundation), Set(PracticeLesson.allCases), "No lesson may be lost when the libraries merge")
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        // Lesson rows keep the identifier they had in the old libraries.
        XCTAssertEqual(PathLesson.lesson(.pulse).id, "lesson-pulse")
        XCTAssertTrue(all.contains(.echo) && all.contains(.celloIntroduction), "Nothing sits outside the levels")
    }

    func testNextLessonIsTheFirstUnfinishedLessonOnThePath() {
        XCTAssertEqual(Level.nextLesson { _ in false }?.step, .lesson(.steadyHum))
        XCTAssertNil(Level.nextLesson { _ in true })

        let firstLevel = Set(Level.path[0].lessons)
        let afterFirstLevel = Level.nextLesson { firstLevel.contains($0) }
        XCTAssertEqual(afterFirstLevel?.level.id, "hotCrossBuns")
        XCTAssertEqual(afterFirstLevel?.step, .listen(.hotCrossBuns))

        // A later lesson done out of order does not move the suggestion past an earlier gap.
        let skippedAhead = Level.nextLesson { $0 != .lesson(.matchHum) }
        XCTAssertEqual(skippedAhead?.step, .lesson(.matchHum))
    }

    func testTheCelloLevelComesLastOnThePath() {
        let beforeCello = Set(Level.path.dropLast().flatMap(\.lessons))
        let next = Level.nextLesson { beforeCello.contains($0) }
        XCTAssertEqual(next?.level.id, "cello")
        XCTAssertEqual(next?.step, .celloIntroduction)
    }

    func testALessonShowsTheWeakestBestScoreAcrossItsParts() {
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [1, 2])]).bestStars, 2)
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [3]), PracticeProgress(stars: [2, 1])]).bestStars, 2)
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [3]), PracticeProgress(stars: [])]).bestStars, 0,
                       "An untried phrase keeps the lesson's stars empty")
        XCTAssertEqual(PracticeProgress(stars: [], alreadyCompleted: true).bestStars, 3)
        XCTAssertNil(PracticeProgress(stars: []).bestStars)
    }

    func testALessonKnowsItsPlaceAndItsNeighboursInsideItsLevel() {
        let first = Level.position(of: .lesson(.steadyHum))
        XCTAssertEqual(first?.label, "Lesson 1 of 6")
        XCTAssertNil(first?.previous, "The first lesson of a level has no previous lesson")
        XCTAssertEqual(first?.next, .lesson(.matchHum))

        let last = Level.position(of: .echo)
        XCTAssertEqual(last?.label, "Lesson 6 of 6")
        XCTAssertEqual(last?.previous, .lesson(.mixedRhythm))
        XCTAssertNil(last?.next, "The lesson bar stays inside the level")

        let notes = Level.position(of: .meetNotes(.odeToJoy))
        XCTAssertEqual(notes?.level.id, "odeToJoy")
        XCTAssertEqual(notes?.label, "Lesson 3 of 5")
        XCTAssertEqual(notes?.previous, .tap(.odeToJoy))
        XCTAssertEqual(notes?.next, .hum(.odeToJoy))
        for step in Level.path.flatMap(\.lessons) { XCTAssertNotNil(Level.position(of: step)) }
    }

    func testStoredIDsAreRememberedOnceEach() {
        var stored = ""
        XCTAssertFalse(StoredIDs.contains("hotCrossBuns", in: stored))
        stored = StoredIDs.adding("odeToJoy", to: stored)
        stored = StoredIDs.adding("odeToJoy", to: stored)
        XCTAssertEqual(stored, "odeToJoy")
        stored = StoredIDs.adding("hotCrossBuns", to: stored)
        XCTAssertTrue(StoredIDs.contains("hotCrossBuns", in: stored))
        XCTAssertTrue(StoredIDs.contains("odeToJoy", in: stored))
        XCTAssertFalse(StoredIDs.contains("ode", in: stored), "Only whole identifiers match")
        XCTAssertEqual(stored, "odeToJoy,hotCrossBuns")
    }

    // MARK: Passed, gold and roll-ups

    func testOneTwoStarAttemptPassesAndGoldKeepsItsOwnRule() {
        XCTAssertFalse(PracticeProgress(stars: []).passed)
        XCTAssertFalse(PracticeProgress(stars: [1, 0, 1]).passed)
        let passed = PracticeProgress(stars: [1, 2])
        XCTAssertTrue(passed.passed)
        XCTAssertFalse(passed.completed, "Passing is not gold")
        XCTAssertEqual(passed.successfulAttempts, 0)

        // An old pass still counts however many weaker attempts follow it.
        XCTAssertTrue(PracticeProgress(stars: [0, 0, 0, 0, 0, 0, 2]).passed)

        let gold = PracticeProgress(stars: [3, 1, 3, 2, 3])
        XCTAssertTrue(gold.completed && gold.passed)
        XCTAssertEqual(gold.successfulAttempts, 3)
        XCTAssertFalse(PracticeProgress(stars: [3, 1, 1, 1, 3, 3]).completed, "Gold needs three among the last five")
    }

    func testEarnedGoldCountsAsPassedEvenWithoutItsTakes() {
        let kept = PracticeProgress(stars: [], alreadyCompleted: true)
        XCTAssertTrue(kept.completed && kept.passed)
        XCTAssertEqual(kept.successfulAttempts, CompletionRule.requiredSuccesses)
    }

    func testPhraseLessonRollsUpItsFourPhrases() {
        let none = PracticeProgress(stars: [])
        let tried = PracticeProgress(stars: [1])
        let passed = PracticeProgress(stars: [2])
        let gold = PracticeProgress(stars: [3, 3, 3])

        let untouched = LessonProgress([none, none, none, none])
        XCTAssertEqual(untouched.status, "0 of 4 phrases passed")
        XCTAssertEqual(LessonProgress([none, passed, none], partNoun: "notes").status, "1 of 3 notes passed")
        XCTAssertFalse(untouched.passed || untouched.started)

        let partial = LessonProgress([gold, passed, tried, none])
        XCTAssertEqual(partial.status, "2 of 4 phrases passed")
        XCTAssertTrue(partial.started)
        XCTAssertFalse(partial.passed)

        let allPassed = LessonProgress([gold, passed, passed, gold])
        XCTAssertTrue(allPassed.passed)
        XCTAssertFalse(allPassed.gold, "Gold needs every phrase's gold")
        XCTAssertEqual(allPassed.status, "Passed")

        let allGold = LessonProgress([gold, gold, gold, gold])
        XCTAssertTrue(allGold.gold && allGold.passed)
        XCTAssertEqual(allGold.status, "Gold")
    }

    func testSingleLessonStatusAndLessonsWithoutProgress() {
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [])]).status, "Not started")
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [])], started: true).status, "In progress")
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [1])]).status, "Not started",
                       "A one-star attempt alone is reported by the caller as started")
        XCTAssertEqual(LessonProgress([PracticeProgress(stars: [2])]).status, "Passed")
        let untracked = LessonProgress([])
        XCTAssertFalse(untracked.passed || untracked.gold, "A lesson with nothing to earn is never passed")
    }

    func testLevelCountsPassedLessonsAndCompletesWhenAllArePassed() {
        let level = Level.path[1]
        let passed: Set<PathLesson> = [.listen(.hotCrossBuns), .tap(.hotCrossBuns)]
        XCTAssertEqual(level.passedLessons { passed.contains($0) }, 2)
        XCTAssertFalse(level.isComplete { passed.contains($0) })
        XCTAssertTrue(level.isComplete { _ in true })
    }

    func testALevelIsCelebratedOnceAndTheFurthestOneFirst() {
        let firstLevel = Set(Level.path[0].lessons)
        XCTAssertNil(Level.newlyCompleted(celebrated: "") { _ in false })
        XCTAssertEqual(Level.newlyCompleted(celebrated: "") { firstLevel.contains($0) }?.id, "firstSounds")
        XCTAssertNil(Level.newlyCompleted(celebrated: "firstSounds") { firstLevel.contains($0) })
        XCTAssertEqual(Level.newlyCompleted(celebrated: "firstSounds") { _ in true }?.id, "cello")
    }
}
