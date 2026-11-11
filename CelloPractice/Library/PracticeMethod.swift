import Foundation

/// How a pitch lesson is practised. The lesson and its goals stay the same; the
/// sound to match, the instructions and what is recorded follow the method.
/// Progress is kept for each method, and either one passes the lesson.
enum PracticeMethod: String, CaseIterable, Identifiable {
    case voice, cello

    /// The cello's side of Steady note: the four open strings, low to high.
    static let openStrings: [Exercise] = [.openC, .openG, .openD, .openA]

    var id: String { rawValue }
    var title: String { self == .voice ? "Voice" : "Cello" }
}
