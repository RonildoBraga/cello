import CelloPitch
import XCTest
@testable import Cello

/// The note under a melody take's stars: what mattered most, what to try, and one more thing.
final class TeacherNoteTests: XCTestCase {
    private let b2 = 123.47, a2 = 110.0, g2 = 98.0

    /// One asked note and how it was heard. `cents` nil means it was not heard at all.
    private func note(_ index: Int, _ frequency: Double, cents: Double? = 0, late: Double = 0, length: Double = 1,
                      matched: Bool? = nil, timed: Bool? = nil, clear: Bool = true) -> MelodyNoteResult {
        let slack = min(0.20, length * 0.35)
        return MelodyNoteResult(expectedIndex: index, expectedStart: Double(index) * length, expectedDuration: length,
            expectedFrequency: frequency, observedFrequency: cents.map { frequency * pow(2, $0 / 1_200) },
            observedOnset: cents == nil ? nil : Double(index) * length + late,
            matched: matched ?? (cents.map { abs($0) < 60 } ?? false), timed: timed ?? (cents != nil && abs(late) <= slack),
            clear: clear && cents != nil, octaveMismatch: false)
    }

    private func rating(_ notes: [MelodyNoteResult], strays: [MelodyStray]? = nil, version: Int = MelodyRating.currentVersion) -> MelodyRating {
        let share = { (kept: Int) in Double(kept) / Double(notes.count) >= 0.8 }
        return MelodyRating(version: version, status: .rated, notes: share(notes.filter(\.matched).count),
                            timing: share(notes.filter(\.timed).count), clarity: share(notes.filter(\.clear).count),
                            noteResults: notes, strays: strays)
    }

    private func text(_ rating: MelodyRating, register: MelodyRegister = .lowVoice, earlier: [MelodyRating] = []) -> [String] {
        TeacherNote(rating: rating, register: register, earlier: earlier).paragraphs
    }

    func testTheTakeThatPromptedTheNote() {
        // Hot Cross Buns, phrase 1, as really sung: B2 a little flat, then each change 0.4 s late
        // after the voice slid up first (to C3, then back up to A2).
        let take = rating([note(0, b2, cents: -67), note(1, a2, cents: -42, late: 0.36), note(2, g2, cents: 36, late: 0.41)],
                          strays: [MelodyStray(time: 0.96, frequency: 130.8), MelodyStray(time: 2.21, frequency: 116.5)])
        let note = TeacherNote(rating: take, register: .lowVoice)
        XCTAssertEqual(note.subject, .late)
        XCTAssertEqual(note.paragraphs, [
            "Notes 2 and 3 began about 0.4 s late, and before each your voice slid up first. Move straight to the next note as its bar reaches the line.",
            "Also: B2 was a little low. Hear the start again and begin on its pitch. A2 and G2 were right."
        ])
        XCTAssertEqual(note.text, note.paragraphs.joined(separator: "\n\n"))
        // With a slide before only one of the late notes, that note is the one named.
        let once = rating([self.note(0, b2), self.note(1, a2, late: 0.36), self.note(2, g2, late: 0.41)],
                          strays: [MelodyStray(time: 0.96, frequency: 130.8)])
        XCTAssertEqual(text(once), ["Notes 2 and 3 began about 0.4 s late, and before note 2 your voice slid up first. Move straight to the next note as its bar reaches the line."])
    }

    func testTimingSaysWhichNotesHowFarAndWhatToDo() {
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, late: 0.31), note(2, g2)])),
                       ["Note 2 began 0.3 s late. Change as its bar reaches the line."])
        XCTAssertEqual(text(rating([note(0, b2, late: 0.45), note(1, a2), note(2, g2)])),
                       ["The first note began 0.5 s late. Start as its bar reaches the line, right after the count of 4."])
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, late: -0.3), note(2, g2, late: -0.3)])),
                       ["Notes 2 and 3 began about 0.3 s early. Wait for each bar to reach the line."])
        // On time, but not held for its length.
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, timed: false), note(2, g2)])),
                       ["Note 2 stopped too soon. Hold it until its bar has passed the line."])
        // Eight quick notes, all late: said once.
        let quick = (0..<8).map { note($0, $0 < 4 ? g2 : a2, late: 0.25, length: 0.5) }
        XCTAssertEqual(text(rating(quick)), ["All the notes began about 0.2 s late. Change note as each bar reaches the line."])
        XCTAssertEqual(text(rating(Array(quick.prefix(1)) + (1..<4).map { note($0, g2, length: 0.5) } + quick.suffix(4))),
                       ["Notes 1, 5, 6, 7 and 8 began about 0.2 s late. Change note as each bar reaches the line."])
    }

    func testPitchSaysWhichWayHowFarAndWhatWasRight() {
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, cents: -100), note(2, g2)])),
                       ["A2 was a little low. Aim higher on it. B2 and G2 were right."])
        XCTAssertEqual(text(rating([note(0, b2, cents: 150), note(1, a2), note(2, g2)])),
                       ["B2 was high. Hear the start again and begin on its pitch. A2 and G2 were right."])
        XCTAssertEqual(text(rating([note(0, b2, cents: -90), note(1, a2, cents: -90), note(2, g2, cents: -90)])),
                       ["B2, A2 and G2 were a little low. Aim higher on them."])
        XCTAssertEqual(text(rating([note(0, b2, cents: -90), note(1, a2), note(2, g2, cents: 130)])),
                       ["B2 was low and G2 was high. Hear the phrase again and follow each note."])
        // Close on the whole but moving about, when it was heard clearly; otherwise it may only have been cut short.
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, cents: -30, matched: false), note(2, g2)])),
                       ["A2 wavered. Find the note, then keep it steady."])
        let unclear = MelodyRating(status: .rated, notes: false, timing: true, clarity: true,
                                   noteResults: [note(0, b2), note(1, a2, cents: -30, matched: false, clear: false), note(2, g2)])
        XCTAssertEqual(text(unclear), ["Listen to this phrase again and follow each note as it changes."])
        // Where the melody repeats a note, notes go by number.
        let quick = (0..<8).map { note($0, $0 < 4 ? g2 : a2, cents: [2, 3].contains($0) ? 80 : 0, length: 0.5) }
        XCTAssertEqual(text(rating(quick)), ["Notes 3 and 4 were a little high. Aim lower on them."])
        XCTAssertEqual(text(rating([note(0, g2), note(1, g2, cents: 80), note(2, g2), note(3, g2)])),
                       ["Note 2 (G2) was a little high. Aim lower on it."])
    }

    func testOneMissedNoteInFiveStillEarnsNotesSoNothingIsSaidAboutIt() {
        let take = rating([note(0, g2), note(1, g2, cents: 80), note(2, g2), note(3, g2), note(4, g2)])
        XCTAssertTrue(take.notes)
        XCTAssertEqual(TeacherNote(rating: take, register: .lowVoice).subject, .allGood)
    }

    func testNotesThatWereNotHeardComeBeforeAnythingAboutPitch() {
        let take = rating([note(0, g2, length: 0.5), note(1, g2, cents: nil, length: 0.5), note(2, g2, cents: nil, length: 0.5),
                           note(3, g2, cents: 90, length: 0.5)])
        XCTAssertEqual(text(take), ["2 of the 4 notes were heard. Give each note a clear start of its own.",
                                    "Also: Note 4 (G2) was a little high. Aim lower on it."])
    }

    func testTheFindingThatTouchedMostNotesLeads() {
        let take = rating([note(0, b2, cents: -90), note(1, a2, cents: -90, late: 0.3), note(2, g2, cents: -90)])
        XCTAssertEqual(text(take), ["B2, A2 and G2 were a little low. Aim higher on them.",
                                    "Also: Note 2 began 0.3 s late. Change as its bar reaches the line."])
        XCTAssertEqual(TeacherNote(rating: take, register: .lowVoice).subject, .low)
    }

    func testOnTheCelloTheWordsAreForAnInstrument() {
        let d3 = 146.83, e3 = 164.81, fSharp3 = 185.0
        // A slide is another note sounding, not a voice.
        let late = rating([note(0, fSharp3), note(1, e3, late: 0.4), note(2, d3)], strays: [MelodyStray(time: 1.1, frequency: 196)])
        XCTAssertEqual(text(late, register: .cello),
                       ["Note 2 began 0.4 s late, and before it a higher note sounded first. Move straight to the next note as its bar reaches the line."])
        // A flat open string cannot be fingered higher.
        XCTAssertEqual(text(rating([note(0, fSharp3), note(1, e3), note(2, d3, cents: -80)]), register: .cello),
                       ["D3 was a little low. It is an open string: check its tuning. F♯3 and E3 were right."])
        XCTAssertEqual(text(rating([note(0, fSharp3), note(1, e3, cents: -80), note(2, d3)]), register: .cello),
                       ["E3 was a little low. Aim higher on it. F♯3 and D3 were right."])
        XCTAssertEqual(text(rating([note(0, fSharp3), note(1, e3), note(2, d3, cents: -80)])),
                       ["D3 was a little low. Aim higher on it. F♯3 and E3 were right."], "A voice has no strings")
    }

    func testAHabitIsNamedOnlyFromTakesScoredTheSameWay() {
        let late = rating([note(0, b2), note(1, a2, late: 0.3), note(2, g2)])
        let flat = rating([note(0, b2), note(1, a2, cents: -100), note(2, g2)])
        XCTAssertEqual(text(late, earlier: [late, late]).last, "The same was true of your last 2 takes.")
        XCTAssertEqual(text(late, earlier: [late, late, late]).last, "The same was true of your last 3 takes.")
        XCTAssertEqual(text(late, earlier: [late]).count, 1, "Once before is not yet a habit")
        XCTAssertEqual(text(late, earlier: [flat, late, late]).count, 1, "Only takes in a row count")
        // Earlier rules could set a note against the wrong one, so their takes are not compared.
        let older = rating([note(0, b2), note(1, a2, late: 0.3), note(2, g2)], version: 3)
        XCTAssertEqual(text(late, earlier: [older, older]).count, 1)
        let good = rating([note(0, b2), note(1, a2), note(2, g2)])
        XCTAssertEqual(text(good, earlier: [good, good]), ["All three goals reached. Try this phrase again, then move to the next one."])
    }

    func testASlideThatCostNothingIsStillWorthAWordAndAKnockIsNot() {
        let good = [note(0, b2), note(1, a2), note(2, g2)]
        XCTAssertEqual(text(rating(good, strays: [MelodyStray(time: 0.9, frequency: 100)])),
                       ["All three goals reached. Try this phrase again, then move to the next one.",
                        "Also: Before a change your voice dipped first. Move straight to the next note."])
        XCTAssertEqual(text(rating(good, strays: [MelodyStray(time: 0.9, frequency: nil)])).count, 1)
    }

    func testASoundBetweenTwoNotesIsTheVoiceOnItsWayNotADetour() {
        // Stepping down from B2 to A2, a moment on B♭2 lies between them: the voice never went up.
        let passing = [MelodyStray(time: 0.96, frequency: 116.5)]
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, late: 0.36), note(2, g2)], strays: passing)),
                       ["Note 2 began 0.4 s late. Change as its bar reaches the line."])
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2), note(2, g2)], strays: passing)).count, 1)
        // Where the first note was sung flat, the stretch starts from where the voice really was.
        XCTAssertEqual(text(rating([note(0, b2, cents: -55), note(1, a2), note(2, g2)],
                                   strays: [MelodyStray(time: 0.96, frequency: 123.5)])).count, 2, "Back up to B2 from a flat B2 is a detour")
        // Going past the note it was heading for is a detour the other way.
        XCTAssertEqual(text(rating([note(0, b2), note(1, a2, late: 0.36), note(2, g2)],
                                   strays: [MelodyStray(time: 0.96, frequency: 101)])),
                       ["Note 2 began 0.4 s late, and before it your voice dipped first. Move straight to the next note as its bar reaches the line."])
    }

    func testTakesThatCouldNotBeScoredAndWholeOctavesKeepTheirPlainAdvice() {
        XCTAssertEqual(text(MelodyRating(status: .insufficientSound)), ["Go through the whole phrase gently, keeping the longer notes going."])
        XCTAssertEqual(text(MelodyRating(status: .unclear)), ["The sound was not clear enough to score. Try again gently, in a quieter spot."])
        let octave = MelodyRating(status: .rated, octaveMismatch: true, noteResults: [note(0, b2, cents: -1_200)])
        XCTAssertEqual(text(octave), ["That was in a different octave. Hear the reference again and match its first note."])
        XCTAssertEqual(TeacherNote(rating: octave, register: .lowVoice).subject, .octave)
        // Clarity lost with every note clear on its own: the sound between them was not.
        let breathy = MelodyRating(status: .rated, notes: true, timing: true, clarity: false,
                                   noteResults: [note(0, b2), note(1, a2), note(2, g2)])
        XCTAssertEqual(text(breathy), ["Keep a gentle, clear sound going through each note."])
    }

    func testAMelodyTakeGetsANoteAndListenAndEchoKeepsItsOwnWords() throws {
        let phrase = MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase1)
        let late = rating([note(0, b2), note(1, a2, late: 0.3), note(2, g2)])
        func session(_ context: MelodyPracticeContext) -> PracticeSession {
            PracticeSession(id: UUID(), createdAt: Date(), exercise: .listen, duration: 4, notes: "", pitchSamples: [],
                            videoFilename: "recording.mov", melodyContext: context, melodyRating: late)
        }
        XCTAssertEqual(session(phrase).melodyFeedback(), "Note 2 began 0.3 s late. Change as its bar reaches the line.")
        XCTAssertEqual(session(phrase).melodyFeedback(earlier: [late, late]),
                       "Note 2 began 0.3 s late. Change as its bar reaches the line.\n\nThe same was true of your last 2 takes.")
        let echo = try EchoLevel.twoNotes.context(patternIndex: 0, register: .lowVoice)
        XCTAssertEqual(session(echo).melodyFeedback(), late.echoFeedback)
        XCTAssertNil(PracticeSession(id: UUID(), createdAt: Date(), exercise: .steadyHum, duration: 3, notes: "",
                                     pitchSamples: [], videoFilename: "recording.mov").melodyFeedback())
    }
}
