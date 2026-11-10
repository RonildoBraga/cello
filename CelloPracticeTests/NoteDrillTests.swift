import XCTest
@testable import Cello

final class NoteDrillTests: XCTestCase {
    func testEachPieceListsExactlyItsOwnNotesLowestFirst() {
        XCTAssertEqual(NoteDrill.notes(for: .hotCrossBuns).map(\.title), ["G2", "A2", "B2"])
        XCTAssertEqual(NoteDrill.notes(for: .odeToJoy).map(\.title), ["G2", "A2", "B2", "C3", "D3"])
        for piece in MelodyPiece.allCases {
            let humming = piece.humming(register: .lowVoice, section: .whole)
            XCTAssertEqual(Set(NoteDrill.notes(for: piece).flatMap(\.midiNotes)),
                           Set(humming.expectedEvents.compactMap(\.midiNote)),
                           "The notes are the ones the learner will hum in this melody")
        }
    }

    func testTwoPairsFollowTheNotesGoingHigherThenLower() {
        let drills = NoteDrill.drills(for: .hotCrossBuns)
        XCTAssertEqual(drills.count, 5)
        XCTAssertEqual(drills.suffix(2).map(\.title), ["G2 then B2 · going higher", "B2 then G2 · going lower"])
        XCTAssertEqual(NoteDrill.drills(for: .odeToJoy).suffix(2).map(\.midiNotes), [[43, 50], [50, 43]])
        XCTAssertEqual(Set(drills.map(\.id)).count, drills.count)
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
        for piece in MelodyPiece.allCases {
            for drill in NoteDrill.drills(for: piece) {
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
        XCTAssertEqual(single.referenceCaption?.text, "G2")
        let pair = VoicePracticeMode.phrase(NoteDrill.drills(for: .hotCrossBuns)[3].context)
        XCTAssertEqual(pair.hearLabel, "Hear notes")
        XCTAssertEqual(pair.referenceCaption?.text, "G2 then B2")
        XCTAssertEqual(VoicePracticeMode.phrase(MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase1)).hearLabel,
                       "Hear phrase")
    }
}
