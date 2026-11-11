import SwiftUI

private struct OpenPathLessonKey: EnvironmentKey {
    static let defaultValue: ((PathLesson) -> Void)? = nil
}

extension EnvironmentValues {
    /// Opens another lesson of the path from inside a lesson's screen. The Music
    /// tab provides it; without it the lesson bar shows where you are only.
    var openPathLesson: ((PathLesson) -> Void)? {
        get { self[OpenPathLessonKey.self] }
        set { self[OpenPathLessonKey.self] = newValue }
    }
}

private struct CurrentPathLessonKey: EnvironmentKey {
    static let defaultValue: PathLesson? = nil
}

extension EnvironmentValues {
    /// The lesson the screen on show belongs to. The Music tab sets it for each
    /// lesson's screen, and the bottom action bar reads it to show the lesson bar.
    var currentPathLesson: PathLesson? {
        get { self[CurrentPathLessonKey.self] }
        set { self[CurrentPathLessonKey.self] = newValue }
    }
}

private struct PathLessonIsPassedKey: EnvironmentKey {
    static let defaultValue: ((PathLesson) -> Bool)? = nil
}

extension EnvironmentValues {
    /// Whether a lesson has been passed, asked afresh each time the bar is drawn.
    var pathLessonIsPassed: ((PathLesson) -> Bool)? {
        get { self[PathLessonIsPassedKey.self] }
        set { self[PathLessonIsPassedKey.self] = newValue }
    }
}

/// The top of every lesson's screen: which level this is, the lesson's title and
/// a plain line about what to do.
struct LessonHeader: View {
    /// Set by a screen that belongs to no lesson of its own, such as Meet your cello.
    var title: String? = nil
    var subtitle: String? = nil
    var collapsesSubtitle = false
    var titleIdentifier = "screenTitle"
    var eyebrowIdentifier = "screenEyebrow"

    @Environment(\.currentPathLesson) private var lesson

    var body: some View {
        ScreenHeader(eyebrow: lesson.flatMap(Level.position).map { "Level \($0.level.number) · \($0.level.title)" },
                     title: title ?? lesson?.title ?? "", subtitle: subtitle,
                     titleIdentifier: titleIdentifier, eyebrowIdentifier: eyebrowIdentifier,
                     collapsesSubtitle: collapsesSubtitle)
    }
}

/// Where the learner is among a lesson's parts (its phrases or notes), for
/// lessons that have several. The lesson bar moves through the parts first and
/// then on to the next lesson, so there is one way forward.
struct LessonParts {
    /// "Phrase 2 of 4".
    let label: String
    let previous: (() -> Void)?
    let next: (title: String, action: () -> Void)?
    /// Whether the part on show has been passed.
    let passed: Bool

    /// The parts as a list, with the current one and how to show another.
    init<Part: Equatable>(_ parts: [Part], current: Part, noun: String, title: (Part) -> String,
                          passed: Bool, show: @escaping (Part) -> Void) {
        let index = parts.firstIndex(of: current) ?? 0
        label = "\(noun) \(index + 1) of \(parts.count)"
        previous = index > 0 ? { show(parts[index - 1]) } : nil
        next = index + 1 < parts.count ? (title(parts[index + 1]), { show(parts[index + 1]) }) : nil
        self.passed = passed
    }
}

/// "‹  Lesson 2 of 5 · Phrase 1 of 4   Next: Phrase 2 ›": the one control for
/// moving on. It steps through a lesson's parts, then to the next lesson, then
/// into the next level, and back the same way. Next becomes a solid button once
/// what is on show has been passed. The bar sits at the bottom of a lesson's
/// screen, just above the main button.
struct LessonBar: View {
    let position: LessonPosition
    var parts: LessonParts? = nil
    @Environment(\.openPathLesson) private var open
    @Environment(\.pathLessonIsPassed) private var isPassed
    @Environment(\.currentPathLesson) private var current
    @Environment(\.isEnabled) private var isEnabled

    private var back: (spoken: String, action: () -> Void)? {
        if let previous = parts?.previous { return ("Previous part", previous) }
        guard let lesson = position.previous, let open else { return nil }
        return ("Previous lesson, \(lesson.title)", { open(lesson) })
    }

    private var forward: (title: String, spoken: String, action: () -> Void)? {
        if let next = parts?.next { return (next.title, "Next part, \(next.title)", next.action) }
        guard let lesson = position.onward, let title = position.onwardTitle,
              let spoken = position.onwardSpoken, let open else { return nil }
        return (title, spoken, { open(lesson) })
    }

    /// Passing what is on show is what makes moving on the suggested thing to do.
    private var suggestsNext: Bool {
        guard forward != nil else { return false }
        if let parts, parts.next != nil { return parts.passed }
        return current.map { isPassed?($0) ?? false } ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { back?.action() } label: {
                Image(systemName: "chevron.left").font(.footnote.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                .disabled(back == nil).opacity(back == nil ? 0.25 : 1)
                .accessibilityLabel(back?.spoken ?? "Previous lesson")
                .accessibilityIdentifier("previousLessonButton")
            VStack(alignment: .leading, spacing: 1) {
                Text(position.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("lessonPosition")
                if let parts {
                    Text(parts.label).font(.caption2).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("lessonPartPosition")
                }
            }
            Spacer(minLength: 4)
            Button { forward?.action() } label: {
                HStack(spacing: 6) {
                    if let forward { Text(suggestsNext ? "Next: \(forward.title)" : forward.title).lineLimit(1) }
                    Image(systemName: "chevron.right")
                }.font(.caption.weight(.semibold))
                    .foregroundStyle(suggestsNext ? .white : Palette.forest)
                    .padding(.horizontal, suggestsNext ? 12 : 8).frame(minWidth: 44, minHeight: suggestsNext ? 34 : 44)
                    .background(suggestsNext ? Palette.forest : .clear, in: Capsule())
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .disabled(forward == nil).opacity(forward == nil ? 0.25 : 1)
                .accessibilityLabel(forward?.spoken ?? "Next lesson")
                .accessibilityValue(suggestsNext ? "Suggested" : "")
                .accessibilityIdentifier("nextLessonButton")
        }.padding(.horizontal, 6)
            .background(Palette.forest.opacity(0.06), in: RoundedRectangle(cornerRadius: Layout.tileRadius))
            .opacity(isEnabled ? 1 : 0.45)
    }
}
