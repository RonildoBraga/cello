import XCTest
@testable import Cello

/// The room is measured so a noisy one can be named. Scoring does not use it.
/// The levels below come from real takes: a quiet room near 0.0002, a hum near 0.0045.
final class RoomNoiseTests: XCTestCase {
    private let quiet = 0.0002, hum = 0.0045

    func testTheLevelOfASoundIgnoresAConstantOffset() {
        let wave = (0..<4_800).map { Float(0.01 * sin(2 * Double.pi * 100 * Double($0) / 48_000)) }
        XCTAssertEqual(RoomNoise.level(of: wave), 0.01 / 2.0.squareRoot(), accuracy: 1e-5)
        XCTAssertEqual(RoomNoise.level(of: wave.map { $0 + 0.2 }), RoomNoise.level(of: wave), accuracy: 1e-5)
        XCTAssertEqual(RoomNoise.level(of: []), 0)
    }

    func testTheRoomNeedsAMomentOfListeningThenIsItsQuietestTenth() {
        XCTAssertNil(RoomNoise(levels: Array(repeating: quiet, count: RoomNoise.fewest - 1)))
        XCTAssertEqual(RoomNoise(levels: Array(repeating: quiet, count: RoomNoise.fewest))?.level, quiet)
        // A steady fan is the same all the time, so it is measured as it is.
        XCTAssertEqual(RoomNoise(levels: Array(repeating: 0.001, count: 40))?.level, 0.001)
    }

    func testTheLearnerIsNotMistakenForTheRoom() throws {
        // Humming to find the note for nine of the last ten seconds, with one second of quiet.
        let tuning = Array(repeating: hum, count: 90) + Array(repeating: quiet, count: 10)
        XCTAssertEqual(RoomNoise(levels: tuning)?.level, quiet)
        XCTAssertFalse(try XCTUnwrap(RoomNoise(levels: tuning.shuffled())).isLoud)
        // A few empty measurements as the microphone starts do not make a noisy room look silent.
        let starting = [0.0, 0, 0] + Array(repeating: 0.001, count: 37)
        XCTAssertEqual(RoomNoise(levels: starting)?.level, 0.001)
    }

    func testARoomIsNoisyOnceItAloneCountsAsSound() {
        XCTAssertFalse(RoomNoise(level: quiet).isLoud)
        XCTAssertFalse(RoomNoise(level: 0.00079).isLoud)
        XCTAssertTrue(RoomNoise(level: RoomNoise.soundFloor).isLoud, "The level the detector and raters call sound")
        XCTAssertTrue(RoomNoise(level: 0.003).isLoud)
    }

    func testTheTunerHearsOnlySoundThatStandsClearOfTheRoom() {
        // In a quiet room nothing changes: whatever the detector hears is shown.
        XCTAssertTrue(RoomNoise(level: quiet).isClear(RoomNoise.soundFloor))
        // In a noisy room, sound at the room's own level is not a note; a hum is.
        let noisy = RoomNoise(level: 0.0008)
        XCTAssertFalse(noisy.isClear(0.0008))
        XCTAssertFalse(noisy.isClear(0.0019))
        XCTAssertTrue(noisy.isClear(0.002))
        XCTAssertTrue(noisy.isClear(hum))
        // However loud the room reads, a soft hum (0.0026 in the quietest real takes) is still shown.
        XCTAssertTrue(RoomNoise(level: hum).isClear(0.0026))
        XCTAssertFalse(RoomNoise(level: hum).isClear(0.002))
    }

    func testTheScreenHearsAboutTheRoomOnlyWhenItBecomesKnownNoisyOrQuiet() throws {
        var listener = RoomListener()
        // The count of 1–2–3–4 in a quiet room: forty measurements, one piece of news.
        let news = (0..<40).map { _ in listener.hear(quiet) }
        XCTAssertEqual(news.filter { $0 }.count, 1)
        XCTAssertEqual(news.firstIndex(of: true), RoomNoise.fewest - 1, "Known after a second and a half")
        XCTAssertEqual(listener.room?.isLoud, false)
        // A fan is switched on. The room turns noisy only when nearly all that is remembered
        // is the fan, about nine seconds on: sound that comes and goes, like a hum, never does it.
        let fan = (0..<RoomNoise.memory).map { _ in listener.hear(0.001) }
        XCTAssertEqual(fan.filter { $0 }.count, 1)
        XCTAssertGreaterThan(try XCTUnwrap(fan.firstIndex(of: true)), 80)
        XCTAssertEqual(listener.room, RoomNoise(level: 0.001))
        // It turns quiet again a second or so after the fan stops.
        let after = (0..<RoomNoise.memory).map { _ in listener.hear(quiet) }
        XCTAssertEqual(after.filter { $0 }.count, 1)
        XCTAssertLessThan(try XCTUnwrap(after.firstIndex(of: true)), 15)
        XCTAssertEqual(listener.room, RoomNoise(level: quiet))
    }

    func testATakeKeepsItsRoomAndEarlierTakesStillOpenWithoutOne() throws {
        func session(roomLevel: Double?) -> PracticeSession {
            PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), exercise: .steadyHum, duration: 3,
                            notes: "", pitchSamples: [], videoFilename: "recording.mov", roomLevel: roomLevel)
        }
        let noisy = try JSONDecoder().decode(PracticeSession.self, from: JSONEncoder().encode(session(roomLevel: 0.001)))
        XCTAssertEqual(noisy.room, RoomNoise(level: 0.001))
        XCTAssertEqual(noisy.room?.isLoud, true)

        // A take saved before the room was measured has no such field, and saving one adds none.
        let earlier = try JSONEncoder().encode(session(roomLevel: nil))
        XCTAssertFalse(try XCTUnwrap(String(data: earlier, encoding: .utf8)).contains("roomLevel"))
        XCTAssertNil(try JSONDecoder().decode(PracticeSession.self, from: earlier).room)
    }
}
