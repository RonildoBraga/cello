import CelloPitch
import Foundation
@testable import Cello

// The app reads the takes into an index once and asks the ledgers by key.
// Tests state their cases as takes, so they ask the ledgers take by take.

extension SessionProgressLedger {
    func progress(forKey key: String?, sessions: [PracticeSession]) -> PracticeProgress {
        progress(forKey: key, stars: Self.stars(in: sessions))
    }

    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool { update(from: Self.stars(in: sessions)) }
}

extension PracticeProgressLedger {
    func progress(for exercise: Exercise, targetFrequency: Double, sessions: [PracticeSession]) -> PracticeProgress {
        progress(forKey: Self.key(exercise: exercise, targetFrequency: targetFrequency), sessions: sessions)
    }
}

extension MelodyProgressLedger {
    func progress(for context: MelodyPracticeContext, sessions: [PracticeSession]) -> PracticeProgress {
        progress(forKey: Self.key(for: context), sessions: sessions)
    }
}

extension EchoProgressLedger {
    func progress(for level: EchoLevel, register: MelodyRegister, sessions: [PracticeSession]) -> PracticeProgress {
        progress(forKey: Self.key(for: level, register: register), sessions: sessions)
    }
}
