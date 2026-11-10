import Combine
import Foundation

/// The three foundation rhythm histories, created once and looked up by exercise.
@MainActor
final class RhythmStores: ObservableObject {
    private let pulse: PulsePracticeStore
    private let twoTaps: PulsePracticeStore
    private let mixedRhythm: PulsePracticeStore
    private var observers: [AnyCancellable] = []

    init(directory: URL? = nil) {
        pulse = PulsePracticeStore(directory: directory, exercise: .pulse)
        twoTaps = PulsePracticeStore(directory: directory, exercise: .twoTaps)
        mixedRhythm = PulsePracticeStore(directory: directory, exercise: .mixedRhythm)
        // Library screens show every lesson's progress, so any store's change refreshes them.
        observers = [pulse, twoTaps, mixedRhythm].map { store in
            store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }

    func store(for exercise: RhythmExercise) -> PulsePracticeStore {
        switch exercise {
        case .pulse: return pulse
        case .twoTaps: return twoTaps
        case .mixedRhythm: return mixedRhythm
        }
    }
}
