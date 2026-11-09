import Foundation

/// Each learning area remembers its selected lesson independently.
struct PracticeSelection: Equatable {
    var area: LearningArea = .humming
    private var hummingLesson: PracticeLesson = .steadyHum
    private var rhythmLesson: PracticeLesson = .pulse
    private var celloLesson: PracticeLesson = .openG

    init() {}

    var lesson: PracticeLesson {
        switch area {
        case .humming: return hummingLesson
        case .rhythm: return rhythmLesson
        case .cello: return celloLesson
        }
    }

    mutating func select(_ lesson: PracticeLesson) {
        area = lesson.area
        switch lesson.area {
        case .humming: hummingLesson = lesson
        case .rhythm: rhythmLesson = lesson
        case .cello: celloLesson = lesson
        }
    }
}
