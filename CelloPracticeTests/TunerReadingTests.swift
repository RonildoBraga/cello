import Foundation
import XCTest
@testable import Cello

final class TunerReadingTests: XCTestCase {
    func testEchoTunerFollowsFrozenNoteChangesWithoutMovingTheMeasuredPitch() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            let context = try EchoLevel.twoNotes.context(patternIndex: 1, register: register)
            let first = try XCTUnwrap(context.frequency(for: context.expectedEvents[0]))
            for (time, expectedCents) in [(0.0, 0.0), (1.999, 0), (2.0, -200), (3.999, -200)] {
                let index = try XCTUnwrap(context.eventIndex(at: time))
                let target = try XCTUnwrap(context.frequency(for: context.expectedEvents[index]))
                let reading = TunerReading(frequency: first, targetFrequency: target)
                XCTAssertEqual(try XCTUnwrap(reading.cents), expectedCents, accuracy: 1e-8)
                XCTAssertEqual(reading.frequency, first, "The display never moves the learner's measured pitch onto a new target")
                XCTAssertNil(TunerReading(frequency: nil, targetFrequency: target).cents,
                             "Silence has no tuning judgment")
            }
            XCTAssertNil(context.eventIndex(at: 4), "The final boundary has no active target")
            let repeated = try EchoLevel.twoNotes.context(patternIndex: 0, register: register)
            let repeatedTarget = try XCTUnwrap(repeated.frequency(for: repeated.expectedEvents[1]))
            XCTAssertEqual(try XCTUnwrap(TunerReading(frequency: first, targetFrequency: repeatedTarget).cents), 0,
                           accuracy: 1e-8)
        }
    }

    func testHummingUsesTheHumanExampleForEverySectionInput() {
        XCTAssertEqual(PracticeSection.humming.exercises, [.steadyHum, .matchHum])
        for exercise in Exercise.allCases {
            let selected = PracticeSection.humming.normalizedExercise(exercise)
            XCTAssertEqual(selected.section, .humming)
            XCTAssertEqual(PracticeSection.humming.effectiveTarget(for: exercise), HummingExample.frequency)
            let reading = TunerReading(frequency: HummingExample.frequency,
                                       targetFrequency: PracticeSection.humming.effectiveTarget(for: exercise))
            XCTAssertEqual(reading.cents, 0)
        }
    }

    func testCelloKeepsStringTargetsAndRejectsHummingChoices() throws {
        let section = PracticeSection.cello
        XCTAssertEqual(section.exercises, [.openC, .openG, .openD, .openA])
        for exercise in section.exercises {
            XCTAssertEqual(section.normalizedExercise(exercise), exercise)
            XCTAssertEqual(section.effectiveTarget(for: exercise), try XCTUnwrap(exercise.targetFrequency))
            XCTAssertNotEqual(section.effectiveTarget(for: exercise), HummingExample.frequency)
        }
        for exercise in [Exercise.steadyHum, .matchHum, .listen] {
            XCTAssertEqual(section.normalizedExercise(exercise), .openG)
            XCTAssertEqual(section.effectiveTarget(for: exercise), try XCTUnwrap(Exercise.openG.targetFrequency))
        }
        XCTAssertNil(Exercise.listen.section)
    }

    func testHistoricalVoiceTargetIsNotReplacedByTheNewSectionReference() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","createdAt":"2026-11-09T04:34:50Z","exercise":"steadyHum","duration":3.1,"notes":"","pitchSamples":[],"videoFilename":"recording.mov","tuningTargetFrequency":103.82617439498628}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let historical = try decoder.decode(PracticeSession.self, from: Data(json.utf8))
        XCTAssertEqual(historical.effectiveTargetFrequency, 103.82617439498628)
        XCTAssertNotEqual(historical.effectiveTargetFrequency, PracticeSection.humming.effectiveTarget(for: .steadyHum))
    }

    func testReadingWithoutTargetHasNoTuningJudgment() {
        for frequency in [65.40639132514966, 89.779, 89.885, 220] {
            let reading = TunerReading(frequency: frequency, targetFrequency: nil)
            XCTAssertEqual(reading.frequency, frequency)
            XCTAssertNotEqual(reading.noteName, "—")
            XCTAssertNil(reading.cents)
        }
    }

    func testRecordedSemitoneBoundaryDoesNotReverseFixedTargetDirection() throws {
        let targetF2 = 87.30705785825097
        let before = TunerReading(frequency: 89.779, targetFrequency: targetF2)
        let after = TunerReading(frequency: 89.885, targetFrequency: targetF2)
        XCTAssertEqual(before.noteName, "F2")
        XCTAssertEqual(after.noteName, "F♯2")
        let beforeCents = try XCTUnwrap(before.cents)
        let afterCents = try XCTUnwrap(after.cents)
        XCTAssertGreaterThan(beforeCents, 0)
        XCTAssertGreaterThan(afterCents, 0)
        XCTAssertLessThan(beforeCents, 50)
        XCTAssertGreaterThan(afterCents, 50)
        XCTAssertEqual(afterCents - beforeCents, 1_200 * log2(89.885 / 89.779), accuracy: 1e-8)
        XCTAssertLessThan(afterCents - beforeCents, 3)
    }

    func testOpenStringsAndTwentyFiveCentOffsets() throws {
        let strings = [("C2", 65.40639132514966), ("G2", 97.99885899543733),
                       ("D3", 146.8323839587038), ("A3", 220.0)]
        for (note, target) in strings {
            for offset in [-25.0, 0, 25] {
                let frequency = target * pow(2, offset / 1_200)
                let reading = TunerReading(frequency: frequency, targetFrequency: target)
                XCTAssertEqual(reading.noteName, note)
                XCTAssertEqual(try XCTUnwrap(reading.cents), offset, accuracy: 1e-8)
            }
        }
    }

    func testWrongStringIsImmediatelyIdentified() throws {
        let reading = TunerReading(frequency: 146.8323839587038, targetFrequency: 97.99885899543733)
        XCTAssertEqual(reading.noteName, "D3")
        XCTAssertEqual(try XCTUnwrap(reading.cents), 700, accuracy: 1e-8)
    }

    func testInvalidFrequenciesDoNotProduceReadings() {
        let invalid: [Double?] = [nil, 0, -1, .nan, .infinity, -.infinity]
        for frequency in invalid {
            let reading = TunerReading(frequency: frequency, targetFrequency: 220)
            XCTAssertNil(reading.frequency)
            XCTAssertEqual(reading.noteName, "—")
            XCTAssertNil(reading.cents)
        }
    }

    func testInvalidTargetsDoNotInventTuningJudgment() {
        let invalid: [Double?] = [nil, 0, -1, .nan, .infinity, -.infinity]
        for target in invalid {
            let reading = TunerReading(frequency: 220, targetFrequency: target)
            XCTAssertEqual(reading.frequency, 220)
            XCTAssertEqual(reading.noteName, "A3")
            XCTAssertNil(reading.cents)
        }
    }

    func testExtremeFiniteFrequenciesRemainSafe() throws {
        for frequency in [Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude] {
            let reading = TunerReading(frequency: frequency, targetFrequency: 220)
            XCTAssertEqual(reading.frequency, frequency)
            XCTAssertNotEqual(reading.noteName, "—")
            XCTAssertTrue(try XCTUnwrap(reading.cents).isFinite)
        }
    }
}
