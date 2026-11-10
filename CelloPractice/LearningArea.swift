import Foundation

/// Navigation areas are independent of recording sections and pitch targets.
enum LearningArea: String, CaseIterable, Identifiable, Hashable {
    case humming, rhythm, cello

    var id: String { rawValue }

    var title: String {
        switch self {
        case .humming: return "Humming"
        case .rhythm: return "Rhythm"
        case .cello: return "Cello"
        }
    }
}
