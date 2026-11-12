import XCTest
@testable import Cello

/// The lane and the per-note feedback that tell a learner when to change note.
final class HummingGuidanceTests: XCTestCase {
    func testAPhraseBecomesNamedBarsWithPausesAndHigherNotesHigher() {
        let context = MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase1)
        let marks = VoicePracticeMode.phrase(context).laneMarks
        XCTAssertEqual(marks.map(\.label), ["B2", "A2", "G2"])
        XCTAssertEqual(marks.map(\.start), [0, 1, 2])
        // Each bar stops short of the next note: that gap is the pause.
        XCTAssertEqual(marks[0].length, 0.88, accuracy: 1e-9)
        XCTAssertEqual(marks[2].length, 1.76, accuracy: 1e-9)
        XCTAssertEqual(marks.map(\.level), [1, 0.5, 0], "A higher note sits higher on the lane")
    }

    func testEchoBarsShowTimingOnlySoTheCountInGivesNothingAway() {
        let pattern = EchoLevel.twoNotes.pattern(0, register: .lowVoice)
        let marks = VoicePracticeMode.echo(pattern, level: .twoNotes).laneMarks
        XCTAssertEqual(marks.count, 2)
        XCTAssertEqual(marks.map(\.start), [0, 2])
        XCTAssertTrue(marks.allSatisfy { $0.label == nil && $0.level == 0.5 })
    }

    func testASingleNoteIsOneBarForItsWholeLengthAndCelloTakesHaveNoLane() {
        let steady = VoicePracticeMode.note(.steadyHum).laneMarks
        XCTAssertEqual(steady, [LaneMark(start: 0, length: 3, label: "A2")])
        XCTAssertTrue(VoicePracticeMode.note(.openC).laneMarks.isEmpty, "A take that runs until Stop has no set length")
        let drill = VoicePracticeMode.phrase(NoteDrill.notes(for: .hotCrossBuns)[0].context).laneMarks
        XCTAssertEqual(drill.map(\.label), ["G2"])
        XCTAssertEqual(drill[0].level, 0.5)
    }

    func testTheTunerOffersEachDifferentNoteOnceAndOnlyWhenThereAreSeveral() {
        let phrase = VoicePracticeMode.phrase(MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .whole))
        XCTAssertEqual(phrase.tunerTargets.map { TunerReading(frequency: $0, targetFrequency: nil).noteName },
                       ["B2", "A2", "G2"], "In the order the notes first sound")
        XCTAssertEqual(phrase.tunerTargets.first, phrase.target(at: 0), "The first note is the one chosen to begin with")
        XCTAssertTrue(VoicePracticeMode.note(.steadyHum).tunerTargets.isEmpty)
        XCTAssertTrue(VoicePracticeMode.phrase(NoteDrill.notes(for: .hotCrossBuns)[0].context).tunerTargets.isEmpty)
        let pattern = EchoLevel.twoNotes.pattern(0, register: .lowVoice)
        XCTAssertTrue(VoicePracticeMode.echo(pattern, level: .twoNotes).tunerTargets.isEmpty,
                      "Echo keeps its notes secret")
    }

    func testTheTunerShowsTheSameToleranceTheTakeIsScoredWith() {
        // One held note must sit within 25 cents; a melody's notes have 70 either side.
        XCTAssertEqual(VoicePracticeMode.note(.steadyHum).tolerance, RecordingRater.matchCents)
        XCTAssertEqual(VoicePracticeMode.note(.openG).tolerance, 25)
        let phrase = VoicePracticeMode.phrase(MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase3))
        XCTAssertEqual(phrase.tolerance, MelodyRecordingRater.matchCents)
        XCTAssertEqual(VoicePracticeMode.phrase(NoteDrill.notes(for: .hotCrossBuns)[0].context).tolerance, 70)
        // Listen & Echo words what the bar shows: anywhere in the band is close, outside it is not.
        let pattern = EchoLevel.twoNotes.pattern(0, register: .lowVoice)
        let echo = VoicePracticeMode.echo(pattern, level: .twoNotes)
        let target = try? XCTUnwrap(echo.target(at: 0))
        func message(cents: Double) -> String? {
            target.flatMap { echo.recordingMessage(target: $0, reading: TunerReading(frequency: $0 * pow(2, cents / 1_200), targetFrequency: $0)) }
        }
        XCTAssertEqual(message(cents: 60)?.hasPrefix("Close to"), true)
        XCTAssertEqual(message(cents: -69)?.hasPrefix("Close to"), true)
        XCTAssertEqual(message(cents: 75)?.hasPrefix("Above"), true)
        XCTAssertEqual(message(cents: -75)?.hasPrefix("Below"), true)
    }

    func testListenAndEchoNamesTheNoteThatChangedLateAndByHowMuch() {
        // The commonest real mistake: the second of two notes starting late.
        let rating = rating([note(0, start: 0, onset: 0, timed: true),
                             note(1, start: 2, onset: 2.31, frequency: 123.47, timed: false)])
        XCTAssertEqual(rating.timingAdvice, "Note 2 (B2) started 0.3 s late. Change as its bar reaches the line.")
        XCTAssertEqual(rating.echoFeedback, rating.timingAdvice)
        let early = self.rating([note(0, start: 0, onset: 0, timed: true), note(1, start: 2, onset: 1.7, timed: false)])
        XCTAssertTrue(try XCTUnwrap(early.timingAdvice).contains("started 0.3 s early"))
        let lateStart = self.rating([note(0, start: 0, onset: 0.45, timed: false), note(1, start: 2, onset: 2, timed: true)])
        XCTAssertEqual(lateStart.timingAdvice,
                       "The first note (A2) started 0.5 s late. Start as its bar reaches the line, right after the count of 4.")
        let cutShort = self.rating([note(0, start: 0, onset: 0.05, timed: false), note(1, start: 2, onset: 2, timed: true)])
        XCTAssertEqual(cutShort.timingAdvice, "The first note (A2) stopped too soon. Hold it until its bar has passed the line.")
        let unheard = self.rating([note(0, start: 0, onset: 0, timed: true), note(1, start: 2, onset: nil, timed: false)])
        XCTAssertNil(unheard.timingAdvice)
    }

    private func note(_ index: Int, start: Double, onset: Double?, frequency: Double = 110, timed: Bool) -> MelodyNoteResult {
        MelodyNoteResult(expectedIndex: index, expectedStart: start, expectedDuration: 2, expectedFrequency: frequency,
                         observedFrequency: frequency, observedOnset: onset, matched: true, timed: timed, clear: true,
                         octaveMismatch: false)
    }

    private func rating(_ notes: [MelodyNoteResult]) -> MelodyRating {
        MelodyRating(status: .rated, notes: true, timing: false, clarity: true, noteResults: notes)
    }
}
