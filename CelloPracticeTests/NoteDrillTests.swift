import CelloPitch
import XCTest
@testable import Cello

final class NoteDrillTests: XCTestCase {
    func testEachPieceListsExactlyItsOwnNotesLowestFirst() {
        XCTAssertEqual(NoteDrill.notes(for: .hotCrossBuns).map(\.title), ["G2", "A2", "B2"])
        XCTAssertEqual(NoteDrill.notes(for: .odeToJoy).map(\.title), ["G2", "A2", "B2", "C3", "D3"])
        XCTAssertEqual(NoteDrill.notes(for: .twinkle).map(\.title), ["G2", "A2", "B2", "C3", "D3", "E3"])
        XCTAssertEqual(NoteDrill.notes(for: .lightlyRow).map(\.title), ["G2", "A2", "B2", "C3", "D3"])
        XCTAssertEqual(NoteDrill.notes(for: .oldMacDonald).map(\.title), ["G2", "A2", "C3", "D3", "E3"])
        XCTAssertEqual(NoteDrill.notes(for: .yankeeDoodle).map(\.title), ["G2", "A2", "B2", "C3", "D3", "E3", "F3"])
        XCTAssertEqual(NoteDrill.notes(for: .gMajorScale).map(\.title), ["G2", "A2", "B2", "C3", "D3", "E3", "F♯3", "G3"])
        for piece in MelodyPiece.allCases {
            let humming = piece.humming(register: .lowVoice, section: .whole)
            XCTAssertEqual(Set(NoteDrill.notes(for: piece).flatMap(\.midiNotes)),
                           Set(humming.expectedEvents.compactMap(\.midiNote)),
                           "The notes are the ones the learner will hum in this melody")
        }
    }

    func testTwoPairsFollowTheNotesGoingHigherThenLower() {
        let drills = NoteDrill.drills(for: .hotCrossBuns)
        XCTAssertEqual(drills[3...4].map(\.title), ["G2 then B2 · going higher", "B2 then G2 · going lower"])
        XCTAssertEqual(NoteDrill.drills(for: .odeToJoy).suffix(2).map(\.midiNotes), [[43, 50], [50, 43]])
        XCTAssertEqual(Set(drills.map(\.id)).count, drills.count)
    }

    func testAMelodyWithAJumpPractisesThatJumpInsteadOfItsLowestAndHighestNotes() {
        // Twinkle opens G G D D: five notes up in one go. Its highest note, E3, is only ever reached by step.
        let drills = NoteDrill.drills(for: .twinkle)
        XCTAssertEqual(drills.map(\.chipLabel), ["G2", "A2", "B2", "C3", "D3", "E3", "G2→D3", "D3→G2"])
        XCTAssertEqual(drills.suffix(2).map(\.title), ["G2 then D3 · going higher", "D3 then G2 · going lower"])
        XCTAssertEqual(NoteDrill.drills(for: .twinkle, register: .cello).suffix(2).map(\.chipLabel), ["D3→A3", "A3→D3"],
                       "On the cello the jump is from the open D string to the open A string")
        XCTAssertTrue(NoteDrill.quickRepeats(for: .twinkle).isEmpty, "Every note lasts a beat or more")
        XCTAssertNil(VoicePracticeMode.phrase(MelodyPiece.twinkle.humming(register: .lowVoice, section: .whole)).quickNotesHint)
        // Hot Cross Buns' only jump is between its lowest and highest notes, and Ode to Joy
        // moves by step alone, so both keep the pairs they have always had.
        XCTAssertEqual(NoteDrill.drills(for: .hotCrossBuns)[3...4].map(\.midiNotes), [[43, 47], [47, 43]])
        XCTAssertEqual(NoteDrill.drills(for: .odeToJoy).map(\.chipLabel),
                       ["G2", "A2", "B2", "C3", "D3", "G2→D3", "D3→G2"])
    }

    func testOldMacDonaldPractisesItsLeapOfASixthInItsOwnKey() {
        // It drops a fourth (C3 to G2) and later leaps a sixth (G2 to E3): the wider move is drilled.
        let drills = NoteDrill.drills(for: .oldMacDonald)
        XCTAssertEqual(drills.map(\.chipLabel), ["G2", "A2", "C3", "D3", "E3", "G2→E3", "E3→G2"])
        XCTAssertEqual(drills.suffix(2).map(\.title), ["G2 then E3 · going higher", "E3 then G2 · going lower"])
        let cello = NoteDrill.drills(for: .oldMacDonald, register: .cello)
        XCTAssertEqual(cello.map(\.chipLabel), ["D3", "E3", "G3", "A3", "B3", "D3→B3", "B3→D3"])
        XCTAssertTrue(drills.allSatisfy { $0.context.referenceKey == "C major" })
        XCTAssertTrue(cello.allSatisfy { $0.context.referenceKey == "G major" })
        XCTAssertTrue(NoteDrill.quickRepeats(for: .oldMacDonald).isEmpty)
        // Earlier melodies' drills keep the key their saved takes were made in.
        XCTAssertTrue(NoteDrill.drills(for: .twinkle).allSatisfy { $0.context.referenceKey == "G major" })
        XCTAssertTrue(NoteDrill.drills(for: .twinkle, register: .cello).allSatisfy { $0.context.referenceKey == "D major" })
    }

    func testYankeeDoodlePractisesItsSevenNotesItsJumpAndItsQuickRepeatedNote() {
        // Its widest move is the drop of a fifth that ends phrase 1 (D3 to G2 for the voice).
        // The G that opens phrases 1 to 3 is sounded twice at half a beat, so it is met on its own too.
        let drills = NoteDrill.drills(for: .yankeeDoodle)
        XCTAssertEqual(drills.map(\.chipLabel), ["G2", "A2", "B2", "C3", "D3", "E3", "F3", "G2→D3", "D3→G2", "C3 ×8"])
        XCTAssertEqual(drills.last?.title, "C3 · 8 quick notes")
        XCTAssertEqual(drills.last?.context.expectedEvents.map(\.durationBeats), Array(repeating: 0.5, count: 8))
        let cello = NoteDrill.drills(for: .yankeeDoodle, register: .cello)
        XCTAssertEqual(cello.map(\.chipLabel), ["D3", "E3", "F♯3", "G3", "A3", "B3", "C4", "D3→A3", "A3→D3", "G3 ×8"])
        XCTAssertTrue(drills.allSatisfy { $0.context.referenceKey == "C major" })
        XCTAssertTrue(cello.allSatisfy { $0.context.referenceKey == "G major" })
        // The quick-notes advice is shown on every phrase that opens with the repeated G, and on the drill.
        let phrase = { VoicePracticeMode.phrase(MelodyPiece.yankeeDoodle.humming(register: .lowVoice, section: $0)) }
        XCTAssertEqual(MelodySection.allCases.map { phrase($0).quickNotesHint != nil }, [true, true, true, true, false])
        XCTAssertNotNil(VoicePracticeMode.phrase(drills[9].context).quickNotesHint)
    }

    func testTheScalePractisesItsEightNotesAndTheOctaveTheSameWayByVoiceAndOnTheCello() {
        // A scale only steps, so the pair is its lowest and highest notes: the octave, up then down.
        for register in [MelodyRegister.lowVoice, .cello] {
            let drills = NoteDrill.drills(for: .gMajorScale, register: register)
            XCTAssertEqual(drills.map(\.chipLabel), ["G2", "A2", "B2", "C3", "D3", "E3", "F♯3", "G3", "G2→G3", "G3→G2"])
            XCTAssertEqual(drills.suffix(2).map(\.title), ["G2 then G3 · going higher", "G3 then G2 · going lower"])
            XCTAssertTrue(drills.allSatisfy { $0.context.referenceKey == "G major" })
        }
        XCTAssertTrue(NoteDrill.quickRepeats(for: .gMajorScale).isEmpty)
    }

    func testLightlyRowPractisesItsSkipOverANote() {
        // It opens D3 then B2: down over C3. Its widest move is that skip, so the pair is the skip.
        let drills = NoteDrill.drills(for: .lightlyRow)
        XCTAssertEqual(drills.map(\.chipLabel), ["G2", "A2", "B2", "C3", "D3", "B2→D3", "D3→B2"])
        XCTAssertEqual(drills.suffix(2).map(\.title), ["B2 then D3 · going higher", "D3 then B2 · going lower"])
        XCTAssertEqual(NoteDrill.drills(for: .lightlyRow, register: .cello).map(\.chipLabel),
                       ["D3", "E3", "F♯3", "G3", "A3", "F♯3→A3", "A3→F♯3"])
        XCTAssertTrue(NoteDrill.quickRepeats(for: .lightlyRow).isEmpty, "Every note lasts a beat or more")
        XCTAssertNil(VoicePracticeMode.phrase(MelodyPiece.lightlyRow.humming(register: .lowVoice, section: .whole)).quickNotesHint)
    }

    func testAMelodysQuickRepeatedNotesAreMetOnTheirOwnBeforeThePhraseThatNeedsThem() {
        // Hot Cross Buns' third phrase is four quick G's then four quick A's.
        let drills = NoteDrill.drills(for: .hotCrossBuns)
        XCTAssertEqual(drills.count, 7)
        let quick = Array(drills.suffix(2))
        XCTAssertEqual(quick, NoteDrill.quickRepeats(for: .hotCrossBuns))
        XCTAssertEqual(quick.map(\.title), ["G2 · 8 quick notes", "A2 · 8 quick notes"])
        XCTAssertEqual(quick.map(\.chipLabel), ["G2 ×8", "A2 ×8"])
        for drill in quick {
            let events = drill.context.expectedEvents
            XCTAssertEqual(events.map(\.onsetBeat), [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], "The speed the melody asks for")
            XCTAssertTrue(events.allSatisfy { $0.durationBeats == 0.5 && $0.midiNote == drill.midiNotes[0] })
            XCTAssertEqual(drill.context.duration, 4)
            XCTAssertTrue(drill.context.repeatsQuickNotes)
        }
        XCTAssertEqual(NoteDrill.quickRepeats(for: .hotCrossBuns, register: .cello).map(\.chipLabel), ["D3 ×8", "E3 ×8"])
        XCTAssertTrue(NoteDrill.quickRepeats(for: .odeToJoy).isEmpty, "Ode to Joy repeats no note quickly")
        XCTAssertEqual(NoteDrill.notes(for: .hotCrossBuns).count, 3, "The lesson still passes on its three notes")

        // The advice goes wherever a note is repeated quickly, and nowhere else.
        let phrase = { VoicePracticeMode.phrase(MelodyPiece.hotCrossBuns.humming(register: $0, section: $1)) }
        XCTAssertTrue(try XCTUnwrap(phrase(.lowVoice, .phrase3).quickNotesHint).contains("doo-doo-doo-doo"))
        XCTAssertTrue(try XCTUnwrap(phrase(.cello, .phrase3).quickNotesHint).contains("play each one separately"))
        XCTAssertNotNil(phrase(.lowVoice, .whole).quickNotesHint)
        XCTAssertNotNil(VoicePracticeMode.phrase(quick[0].context).quickNotesHint)
        XCTAssertNil(phrase(.lowVoice, .phrase1).quickNotesHint)
        XCTAssertNil(VoicePracticeMode.phrase(drills[3].context).quickNotesHint)
        XCTAssertNil(VoicePracticeMode.note(.steadyHum).quickNotesHint)
        XCTAssertNil(VoicePracticeMode.echo(EchoLevel.twoNotes.pattern(0, register: .lowVoice), level: .twoNotes).quickNotesHint,
                     "An echo pattern repeats notes slowly")
    }

    func testEveryDrillIsAValidFrozenContextOfItsOwn() throws {
        for piece in MelodyPiece.allCases {
            for drill in NoteDrill.drills(for: piece) {
                let context = drill.context
                XCTAssertTrue(context.isValid)
                XCTAssertEqual(context.gradingVersion, MelodyRating.currentVersion)
                XCTAssertEqual(context.noteDrillPiece, piece)
                XCTAssertNil(MelodyPiece(rawValue: context.pieceID), "A note take is never mistaken for a phrase")
                XCTAssertNil(EchoLevel.selection(for: context))
                XCTAssertEqual(context.duration, drill.isSingleNote ? 3 : 4)
                let decoded = try JSONDecoder().decode(MelodyPracticeContext.self, from: JSONEncoder().encode(context))
                XCTAssertEqual(decoded, context)
                XCTAssertEqual(VoicePracticeMode(context: decoded), .phrase(context))
            }
        }
        XCTAssertNil(MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase1).noteDrillPiece)
    }

    func testTheRecordedReferenceForEveryDrillEarnsThreeStarsFromTheMelodyRater() throws {
        // Melodies share many drills (G2 alone is in most of them); the same notes sound and score the same.
        var rated: Set<[Double]> = []
        for piece in MelodyPiece.allCases {
            for drill in NoteDrill.drills(for: piece) where rated.insert(drill.midiNotes.map(Double.init) + [drill.noteBeats]).inserted {
                let context = drill.context
                let data = try RecordedReference.wavData(context: context)
                let samples: [Float] = stride(from: 44, to: data.count, by: 2).map { offset in
                    Float(Int16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8)) / 32_768
                }
                let rating = MelodyRecordingRater.rate(samples: samples,
                    sampleRate: Double(RecordedReference.sampleRate), context: context)
                XCTAssertEqual(rating.status, .rated, drill.title)
                XCTAssertEqual(rating.starCount, 3, "\(piece.rawValue) \(drill.title)")
            }
        }
    }

    func testWordingNamesTheNotesInsteadOfAPhrase() {
        let single = VoicePracticeMode.phrase(NoteDrill.notes(for: .hotCrossBuns)[0].context)
        XCTAssertEqual(single.hearLabel, "Hear note")
        XCTAssertEqual(single.hearSpoken, "Hear note, Reference G2")
        let pair = VoicePracticeMode.phrase(NoteDrill.drills(for: .hotCrossBuns)[3].context)
        XCTAssertEqual(pair.hearLabel, "Hear notes")
        XCTAssertEqual(pair.hearSpoken, "Hear notes, Reference G2 then B2")
        let quick = VoicePracticeMode.phrase(NoteDrill.quickRepeats(for: .hotCrossBuns)[0].context)
        XCTAssertEqual(quick.hearSpoken, "Hear notes, Reference G2, 8 quick notes")
        XCTAssertEqual(quick.listenMessage, "Listen to the quick notes")
        XCTAssertEqual(VoicePracticeMode.phrase(MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase1)).hearLabel,
                       "Hear phrase")
    }
}
