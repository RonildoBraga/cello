import XCTest
@testable import Cello

final class LevelTests: XCTestCase {
    func testPathStartsWithFirstSoundsThenOneLevelPerMelody() {
        XCTAssertEqual(Level.path.map(\.id), ["firstSounds", "hotCrossBuns", "odeToJoy"])
        XCTAssertEqual(Level.path.map(\.number), [1, 2, 3])
        XCTAssertEqual(Level.path[0].steps, [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse), .lesson(.twoTaps)])
    }

    func testEveryMelodyLevelHasTheSameStepsInTheSameOrder() {
        for (level, piece) in zip(Level.path.dropFirst(), MelodyPiece.allCases) {
            XCTAssertEqual(level.title, piece.title)
            XCTAssertEqual(level.steps, [.listen(piece), .tap(piece), .meetNotes(piece), .hum(piece), .wholeMelody(piece)])
            XCTAssertEqual(level.steps.map(\.title), ["Listen", "Tap it", "Meet the notes", "Hum it", "Whole melody"])
        }
    }

    func testEveryLessonAppearsExactlyOnceAndStepIdentifiersAreUnique() {
        let steps = (Level.path + Level.extras).flatMap(\.steps)
        let lessons = steps.compactMap { step -> PracticeLesson? in
            if case .lesson(let lesson) = step { return lesson }
            return nil
        }
        XCTAssertEqual(lessons.count, PracticeLesson.allCases.count)
        XCTAssertEqual(Set(lessons), Set(PracticeLesson.allCases), "No lesson may be lost when the libraries merge")
        XCTAssertEqual(Set(steps.map(\.id)).count, steps.count)
        // Lesson rows keep the identifier they had in the old libraries.
        XCTAssertEqual(PathStep.lesson(.pulse).id, "lesson-pulse")
        XCTAssertTrue(Level.extras.allSatisfy { $0.number == nil })
    }

    func testNextStepIsTheFirstUnfinishedStepOnThePath() {
        XCTAssertEqual(Level.nextStep { _ in false }?.step, .lesson(.steadyHum))
        XCTAssertNil(Level.nextStep { _ in true })

        let firstLevel = Set(Level.path[0].steps)
        let afterFirstLevel = Level.nextStep { firstLevel.contains($0) }
        XCTAssertEqual(afterFirstLevel?.level.id, "hotCrossBuns")
        XCTAssertEqual(afterFirstLevel?.step, .listen(.hotCrossBuns))

        // A later step done out of order does not move the suggestion past an earlier gap.
        let skippedAhead = Level.nextStep { $0 != .lesson(.matchHum) }
        XCTAssertEqual(skippedAhead?.step, .lesson(.matchHum))
    }

    func testStepsOffThePathNeverBecomeTheNextStep() {
        let onPath = Set(Level.path.flatMap(\.steps))
        XCTAssertNil(Level.nextStep { onPath.contains($0) }, "Cello and extra practice stay optional")
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

    func testPhraseStepRollsUpItsFourPhrases() {
        let none = PracticeProgress(stars: [])
        let tried = PracticeProgress(stars: [1])
        let passed = PracticeProgress(stars: [2])
        let gold = PracticeProgress(stars: [3, 3, 3])

        let untouched = StepProgress([none, none, none, none])
        XCTAssertEqual(untouched.status, "0 of 4 phrases passed")
        XCTAssertEqual(StepProgress([none, passed, none], partNoun: "notes").status, "1 of 3 notes passed")
        XCTAssertFalse(untouched.passed || untouched.started)

        let partial = StepProgress([gold, passed, tried, none])
        XCTAssertEqual(partial.status, "2 of 4 phrases passed")
        XCTAssertTrue(partial.started)
        XCTAssertFalse(partial.passed)

        let allPassed = StepProgress([gold, passed, passed, gold])
        XCTAssertTrue(allPassed.passed)
        XCTAssertFalse(allPassed.gold, "Gold needs every phrase's gold")
        XCTAssertEqual(allPassed.status, "Passed")

        let allGold = StepProgress([gold, gold, gold, gold])
        XCTAssertTrue(allGold.gold && allGold.passed)
        XCTAssertEqual(allGold.status, "Gold")
    }

    func testSingleStepStatusAndStepsWithoutProgress() {
        XCTAssertEqual(StepProgress([PracticeProgress(stars: [])]).status, "Not started")
        XCTAssertEqual(StepProgress([PracticeProgress(stars: [])], started: true).status, "In progress")
        XCTAssertEqual(StepProgress([PracticeProgress(stars: [1])]).status, "Not started",
                       "A one-star attempt alone is reported by the caller as started")
        XCTAssertEqual(StepProgress([PracticeProgress(stars: [2])]).status, "Passed")
        let untracked = StepProgress([])
        XCTAssertFalse(untracked.passed || untracked.gold, "A step with nothing to earn is never passed")
    }

    func testLevelCountsPassedStepsAndCompletesWhenAllArePassed() {
        let level = Level.path[1]
        let passed: Set<PathStep> = [.listen(.hotCrossBuns), .tap(.hotCrossBuns)]
        XCTAssertEqual(level.passedSteps { passed.contains($0) }, 2)
        XCTAssertFalse(level.isComplete { passed.contains($0) })
        XCTAssertTrue(level.isComplete { _ in true })
    }

    func testALevelIsCelebratedOnceAndTheFurthestOneFirst() {
        let firstLevel = Set(Level.path[0].steps)
        XCTAssertNil(Level.newlyCompleted(celebrated: "") { _ in false })
        XCTAssertEqual(Level.newlyCompleted(celebrated: "") { firstLevel.contains($0) }?.id, "firstSounds")
        XCTAssertNil(Level.newlyCompleted(celebrated: "firstSounds") { firstLevel.contains($0) })
        XCTAssertEqual(Level.newlyCompleted(celebrated: "firstSounds") { _ in true }?.id, "odeToJoy")
    }
}
