import Foundation

/// Learning goals only. Piece performances earn their own results once those
/// exercises exist; foundation stars never become a fabricated piece score.
enum MusicPiece: String, CaseIterable, Identifiable {
    case hotCrossBuns, bachPrelude

    var id: String { rawValue }
    var title: String {
        self == .hotCrossBuns ? "Hot Cross Buns" : "Bach · Cello Suite No. 1"
    }
    var subtitle: String {
        self == .hotCrossBuns ? "A first three-note melody" : "Prelude · BWV 1007"
    }
    var statusLabel: String {
        self == .hotCrossBuns ? "Humming & rhythm available" : "Long-term goal"
    }
    var summary: String {
        self == .hotCrossBuns
            ? "Build a short melody from three notes, one small phrase at a time."
            : "Build toward fluent notes, bowing and phrasing through foundations and easier pieces."
    }
    var milestones: [(title: String, detail: String)] {
        switch self {
        case .hotCrossBuns:
            return [
                ("Hear & hum", "Learn the three-note pattern and hum back short phrases."),
                ("Tap the rhythm", "Follow note starts and count through longer notes."),
                ("Play on cello", "Set up with a teacher, learn the three notes and join the phrases."),
                ("Play it through", "Bring the notes, rhythm and a steady sound together.")
            ]
        case .bachPrelude:
            return [
                ("Build the foundations", "Develop listening, rhythm and a comfortable cello setup."),
                ("Play beginner pieces", "Learn notes and bow control through short melodies."),
                ("Connect strings and notes", "Develop scales, arpeggios and fluent string crossings."),
                ("Learn the Prelude in phrases", "Work on the notes and bowing in small sections with a teacher."),
                ("Shape the whole piece", "Bring the phrases together with reliable timing and musical direction.")
            ]
        }
    }
}
