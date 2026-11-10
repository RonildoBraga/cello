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
            XCTAssertEqual(level.steps, [.listen(piece), .tap(piece), .hum(piece), .wholeMelody(piece)])
            XCTAssertEqual(level.steps.map(\.title), ["Listen", "Tap it", "Hum it", "Whole melody"])
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

    func testListenedMelodiesAreRememberedOnceEach() {
        var stored = ""
        XCTAssertFalse(ListenedMelodies.contains(.hotCrossBuns, in: stored))
        stored = ListenedMelodies.adding(.odeToJoy, to: stored)
        stored = ListenedMelodies.adding(.odeToJoy, to: stored)
        XCTAssertEqual(stored, "odeToJoy")
        stored = ListenedMelodies.adding(.hotCrossBuns, to: stored)
        XCTAssertTrue(ListenedMelodies.contains(.hotCrossBuns, in: stored))
        XCTAssertTrue(ListenedMelodies.contains(.odeToJoy, in: stored))
        XCTAssertEqual(stored, "odeToJoy,hotCrossBuns")
    }
}
