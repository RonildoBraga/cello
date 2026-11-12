import CelloPitch
import Foundation

// Re-scores saved melody takes with the rater in this checkout and prints what changed,
// so a change to the scoring can be judged on real recordings before it ships.
//
//   swift run --package-path Packages/CelloPitch -c release cello-rescore <folder> [date prefix]
//
// <folder> is searched for takes as the app saves them (a folder holding session.json and
// recording.mov), for example a copy of the app's Documents. With a date prefix such as
// 2026-11-12T02, the takes made then are shown note by note. Nothing is written or sent.

struct SavedTake: Decodable {
    let id: String
    let createdAt: String
    let melodyContext: MelodyPracticeContext?
    let melodyRating: MelodyRating?
}

func kind(_ context: MelodyPracticeContext) -> String {
    if context.pieceID.hasSuffix(".notes") {
        return context.expectedEvents.count == 1 ? "single note" : context.expectedEvents.count == 2 ? "pair" : "quick repeats"
    }
    if context.pieceID.hasPrefix("echo") { return "echo" }
    return context.expectedEvents.contains { $0.durationBeats < 1 } ? "quick phrase" : "phrase"
}

func marks(_ rating: MelodyRating?) -> String {
    guard let rating else { return "unrated" }
    guard rating.status == .rated else { return rating.status.rawValue }
    return (rating.notes ? "N" : "-") + (rating.timing ? "T" : "-") + (rating.clarity ? "C" : "-")
}

func stars(_ rating: MelodyRating?) -> Int { rating?.starCount ?? 0 }

let arguments = CommandLine.arguments.dropFirst()
guard let folder = arguments.first else {
    print("usage: cello-rescore <folder of saved takes> [date prefix, e.g. 2026-11-12T02]")
    exit(2)
}
let detail = arguments.dropFirst().first

// The same take can sit in several backups: the last copy found wins.
var takes: [String: (take: SavedTake, folder: URL)] = [:]
let files = FileManager.default.enumerator(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)
while let file = files?.nextObject() as? URL {
    guard file.lastPathComponent == "session.json", let data = try? Data(contentsOf: file),
          let take = try? JSONDecoder().decode(SavedTake.self, from: data), take.melodyContext != nil else { continue }
    takes[take.id] = (take, file.deletingLastPathComponent())
}

var totals: [String: (takes: Int, passesBefore: Int, passesNow: Int, starsBefore: Int, starsNow: Int)] = [:]
var changed: [String] = [], gained = 0, lost = 0
var history: [(part: MelodyPracticeContext, rating: MelodyRating)] = []
for (take, folder) in takes.values.sorted(by: { $0.take.createdAt < $1.take.createdAt }) {
    guard let saved = take.melodyContext, (saved.gradingVersion ?? 0) >= MelodyRating.progressVersions.lowerBound else { continue }
    let context = saved.graded(by: MelodyRating.currentVersion)
    guard let samples = try? await RecordingAudio.read(url: folder.appendingPathComponent("recording.mov"),
                                                       maximumDuration: min(26, context.duration + 2)) else { continue }
    let rating = MelodyRecordingRater.rate(samples: samples, sampleRate: RecordingAudio.sampleRate, context: context)
    let part = saved.graded(by: 0)
    let note = TeacherNote(rating: rating, register: context.register,
                           earlier: history.reversed().filter { $0.part == part }.prefix(3).map(\.rating))
    history.append((part, rating))

    var total = totals[kind(context)] ?? (0, 0, 0, 0, 0)
    total.takes += 1
    total.passesBefore += stars(take.melodyRating) >= 2 ? 1 : 0
    total.passesNow += stars(rating) >= 2 ? 1 : 0
    total.starsBefore += stars(take.melodyRating)
    total.starsNow += stars(rating)
    totals[kind(context)] = total
    gained += stars(rating) > stars(take.melodyRating) ? 1 : 0
    lost += stars(rating) < stars(take.melodyRating) ? 1 : 0
    let line = "\(take.createdAt)  \(context.pieceID) \(context.section.rawValue)  \(marks(take.melodyRating)) -> \(marks(rating))"
    if marks(rating) != marks(take.melodyRating) { changed.append(line) }
    if let detail, take.createdAt.hasPrefix(detail) {
        print(line)
        for result in rating.noteResults {
            let heard = result.observedFrequency.flatMap { observed in
                result.expectedFrequency.map { String(format: "%+.0f cents", 1_200 * log2(observed / $0)) }
            } ?? "not heard"
            let start = result.observedOnset.map { String(format: "%+.2f s", $0 - result.expectedStart) } ?? "-"
            print("    note \(result.expectedIndex + 1): \(heard), start \(start), matched \(result.matched), timed \(result.timed), clear \(result.clear)")
        }
        for paragraph in note.paragraphs { print("    > \(paragraph)") }
    }
}

print("\nScoring version \(MelodyRating.currentVersion) against each take's saved result")
for (name, total) in totals.sorted(by: { $0.key < $1.key }) {
    print("  \(name.padding(toLength: 13, withPad: " ", startingAt: 0)) \(total.takes) takes, passes \(total.passesBefore) -> \(total.passesNow), stars \(total.starsBefore) -> \(total.starsNow)")
}
print("  \(gained) takes gain stars, \(lost) lose")
for line in changed { print("  " + line) }
