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

/// The top of every lesson's screen: which level this is, the lesson's title and
/// a plain line about what to do.
struct LessonHeader: View {
    let step: PathLesson
    /// Defaults to the lesson's own title.
    var title: String? = nil
    var subtitle: String? = nil
    var collapsesSubtitle = false
    var titleIdentifier = "screenTitle"
    var eyebrowIdentifier = "screenEyebrow"

    var body: some View {
        ScreenHeader(eyebrow: Level.position(of: step).map { "Level \($0.level.number) · \($0.level.title)" },
                     title: title ?? step.title, subtitle: subtitle,
                     titleIdentifier: titleIdentifier, eyebrowIdentifier: eyebrowIdentifier,
                     collapsesSubtitle: collapsesSubtitle)
    }
}

/// "‹  Lesson 1 of 6  Listen & match ›": back to the previous lesson of the level
/// or on to the next. The arrows fade at the first and last lesson. It sits at
/// the bottom of a lesson's screen, just above the main button.
struct LessonBar: View {
    let position: LessonPosition
    @Environment(\.openPathLesson) private var open
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 8) {
            arrow(to: position.previous, symbol: "chevron.left", name: "Previous lesson",
                  identifier: "previousLessonButton")
            Text(position.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("lessonPosition")
            Spacer(minLength: 4)
            if let next = position.next {
                Text(next.title).font(.caption.weight(.medium)).foregroundStyle(Palette.forest)
                    .lineLimit(1).accessibilityHidden(true)
            }
            arrow(to: position.next, symbol: "chevron.right", name: "Next lesson", identifier: "nextLessonButton")
        }.padding(.horizontal, 6)
            .background(Palette.forest.opacity(0.06), in: RoundedRectangle(cornerRadius: Layout.tileRadius))
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func arrow(to step: PathLesson?, symbol: String, name: String, identifier: String) -> some View {
        Button { if let step { open?(step) } } label: {
            Image(systemName: symbol).font(.footnote.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Palette.forest)
            .disabled(step == nil || open == nil).opacity(step == nil ? 0.25 : 1)
            .accessibilityLabel(step.map { "\(name), \($0.title)" } ?? name)
            .accessibilityIdentifier(identifier)
    }
}
