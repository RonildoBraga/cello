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
    var subtitle: String? = nil
    var collapsesSubtitle = false
    var titleIdentifier = "screenTitle"
    var eyebrowIdentifier = "screenEyebrow"

    @Environment(\.currentPathLesson) private var lesson

    var body: some View {
        ScreenHeader(eyebrow: lesson.flatMap(Level.position).map { "Level \($0.level.number) · \($0.level.title)" },
                     title: lesson?.title ?? "", subtitle: subtitle,
                     titleIdentifier: titleIdentifier, eyebrowIdentifier: eyebrowIdentifier,
                     collapsesSubtitle: collapsesSubtitle)
    }
}

/// "‹  Lesson 1 of 6  Listen & match ›": back to the previous lesson of the
/// level, or on to the next. Once this lesson is passed, Next becomes a solid
/// button, and at the end of a level it leads into the next level. The bar sits
/// at the bottom of a lesson's screen, just above the main button.
struct LessonBar: View {
    let position: LessonPosition
    @Environment(\.openPathLesson) private var open
    @Environment(\.pathLessonIsPassed) private var isPassed
    @Environment(\.currentPathLesson) private var current
    @Environment(\.isEnabled) private var isEnabled

    /// Passing the lesson on show is what makes moving on the suggested thing to do.
    private var suggestsNext: Bool {
        guard let current, position.onward != nil else { return false }
        return isPassed?(current) ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { if let previous = position.previous { open?(previous) } } label: {
                Image(systemName: "chevron.left").font(.footnote.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                .disabled(position.previous == nil || open == nil).opacity(position.previous == nil ? 0.25 : 1)
                .accessibilityLabel(position.previous.map { "Previous lesson, \($0.title)" } ?? "Previous lesson")
                .accessibilityIdentifier("previousLessonButton")
            Text(position.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("lessonPosition")
            Spacer(minLength: 4)
            Button { if let onward = position.onward { open?(onward) } } label: {
                HStack(spacing: 6) {
                    if let title = position.onwardTitle {
                        Text(suggestsNext ? "Next: \(title)" : title).lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                }.font(.caption.weight(.semibold))
                    .foregroundStyle(suggestsNext ? .white : Palette.forest)
                    .padding(.horizontal, suggestsNext ? 12 : 8).frame(minWidth: 44, minHeight: suggestsNext ? 34 : 44)
                    .background(suggestsNext ? Palette.forest : .clear, in: Capsule())
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .disabled(position.onward == nil || open == nil).opacity(position.onward == nil ? 0.25 : 1)
                .accessibilityLabel(position.onwardSpoken ?? "Next lesson")
                .accessibilityValue(suggestsNext ? "Suggested" : "")
                .accessibilityIdentifier("nextLessonButton")
        }.padding(.horizontal, 6)
            .background(Palette.forest.opacity(0.06), in: RoundedRectangle(cornerRadius: Layout.tileRadius))
            .opacity(isEnabled ? 1 : 0.45)
    }
}
