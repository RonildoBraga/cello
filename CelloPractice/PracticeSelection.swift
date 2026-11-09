import Foundation

/// Each section remembers one complete lesson selection, including tap lessons.
struct PracticeSelection: Equatable {
    var section: PracticeSection = .humming
    private var hummingLesson: PracticeLesson = .steadyHum
    private var celloLesson: PracticeLesson = .openG

    init() {}

    var lesson: PracticeLesson {
        section == .humming ? hummingLesson : celloLesson
    }

    mutating func select(_ lesson: PracticeLesson) {
        section = lesson.section
        switch lesson.section {
        case .humming: hummingLesson = lesson
        case .cello: celloLesson = lesson
        }
    }
}
