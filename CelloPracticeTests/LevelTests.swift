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
        XCTAssertEqual(Level.nextLesson { _ in false }?.lesson, .lesson(.steadyHum))
        XCTAssertNil(Level.nextLesson { _ in true })

        let firstLevel = Set(Level.path[0].lessons)
        let afterFirstLevel = Level.nextLesson { firstLevel.contains($0) }
        XCTAssertEqual(afterFirstLevel?.level.id, "hotCrossBuns")
        XCTAssertEqual(afterFirstLevel?.lesson, .listen(.hotCrossBuns))

        // A later lesson done out of order does not move the suggestion past an earlier gap.
        let skippedAhead = Level.nextLesson { $0 != .lesson(.matchHum) }
        XCTAssertEqual(skippedAhead?.lesson, .lesson(.matchHum))
    }

    func testTheCelloLevelComesLastOnThePath() {
        let beforeCello = Set(Level.path.dropLast().flatMap(\.lessons))
        let next = Level.nextLesson { beforeCello.contains($0) }
        XCTAssertEqual(next?.level.id, "cello")
        XCTAssertEqual(next?.lesson, .celloIntroduction)
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
        XCTAssertNil(last?.next)
        XCTAssertEqual(last?.onward, .listen(.hotCrossBuns), "The last lesson leads on to the next level")
        XCTAssertEqual(last?.onwardSpoken, "Next level, Hot Cross Buns")
        XCTAssertEqual(first?.onwardSpoken, "Next lesson, Listen & match")
        XCTAssertNil(first?.nextLevel)
        let veryLast = Level.position(of: .lesson(.openA))
        XCTAssertNil(veryLast?.onward, "The path ends at the last lesson of the last level")

        let notes = Level.position(of: .meetNotes(.odeToJoy))
        XCTAssertEqual(notes?.level.id, "odeToJoy")
        XCTAssertEqual(notes?.label, "Lesson 3 of 5")
        XCTAssertEqual(notes?.previous, .tap(.odeToJoy))
        XCTAssertEqual(notes?.next, .hum(.odeToJoy))
        for step in Level.path.flatMap(\.lessons) { XCTAssertNotNil(Level.position(of: step)) }
    }

    func testALessonsPartsStepForwardAndBackAndStopAtTheirEnds() {
        var shown: [String] = []
        let parts = ["Phrase 1", "Phrase 2", "Phrase 3"]
        let first = LessonParts(parts, current: "Phrase 1", noun: "Phrase", title: { $0 }, passed: false) { shown.append($0) }
        XCTAssertEqual(first.label, "Phrase 1 of 3")
        XCTAssertNil(first.previous, "Before the first part comes the previous lesson, not a part")
        XCTAssertEqual(first.next?.title, "Phrase 2")
        first.next?.action()

        let last = LessonParts(parts, current: "Phrase 3", noun: "Phrase", title: { $0 }, passed: true) { shown.append($0) }
        XCTAssertEqual(last.label, "Phrase 3 of 3")
        XCTAssertNil(last.next, "After the last part comes the next lesson")
        XCTAssertTrue(last.passed)
        last.previous?()
        XCTAssertEqual(shown, ["Phrase 2", "Phrase 2"])
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

    func testLevelCountsPassedLessons() {
        let level = Level.path[1]
        let passed: Set<PathLesson> = [.listen(.hotCrossBuns), .tap(.hotCrossBuns)]
        XCTAssertEqual(level.passedLessons { passed.contains($0) }, 2)
        XCTAssertEqual(level.passedLessons { _ in true }, level.lessons.count)
    }
}
