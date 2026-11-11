import Foundation

/// The room's own sound, without the learner: the quietest tenth of what the microphone
/// heard in the ten seconds before a take. The count of 1–2–3–4 is silent and no hum or
/// bowed note lasts ten seconds without a pause, so the learner is not in it. Steady noise
/// (a fan, traffic) is measured well; talk and music that come and go read lower than they sound.
struct RoomNoise: Equatable {
    /// The level the pitch detector and the raters already count as sound. A room this
    /// loud cannot be told from a quiet note, so pauses between notes are lost.
    static let soundFloor = 0.0008
    /// Levels arrive a tenth of a second apart: ten seconds are kept, and a second and a half is enough to judge.
    static let memory = 100
    static let fewest = 15

    /// Root-mean-square level, where 1 is the loudest the microphone reports.
    let level: Double

    init(level: Double) { self.level = level }

    init?(levels: [Double]) {
        guard levels.count >= Self.fewest else { return nil }
        level = levels.sorted()[(levels.count - 1) / 10]
    }

    var isLoud: Bool { level >= Self.soundFloor }

    /// Whether a sound stands clear of the room: two and a half times its level. The bar
    /// stops below a soft hum, so a loud room never hides the learner from the tuner.
    func isClear(_ rms: Double) -> Bool { rms >= min(level * 2.5, Self.soundFloor * 3) }

    /// The level of a stretch of sound, ignoring any constant offset in the signal.
    static func level(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        return (samples.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(samples.count)).squareRoot()
    }

    static let warning = "Noisy room. Bring the phone closer."
    static let resultNote = "The room was noisy during this take, which can lower the score. Bring the phone closer, or try somewhere quieter."
}

/// What the microphone has heard outside a take, and the room that adds up to.
struct RoomListener {
    private var levels: [Double] = []
    private(set) var room: RoomNoise?

    /// Adds a level, measured a tenth of a second after the last. True when the room has
    /// just become known, noisy or quiet: the only moments a screen needs to hear about.
    mutating func hear(_ level: Double) -> Bool {
        levels.append(level)
        if levels.count > RoomNoise.memory { levels.removeFirst() }
        let heard = RoomNoise(levels: levels)
        defer { room = heard }
        return heard?.isLoud != room?.isLoud
    }
}
