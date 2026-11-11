import SwiftUI

private struct OpenPathStepKey: EnvironmentKey {
    static let defaultValue: ((PathStep) -> Void)? = nil
}

extension EnvironmentValues {
    /// Opens another step of the path from inside a step's screen. The Music
    /// tab provides it; without it the step bar shows where you are only.
    var openPathStep: ((PathStep) -> Void)? {
        get { self[OpenPathStepKey.self] }
        set { self[OpenPathStepKey.self] = newValue }
    }
}

private struct CurrentPathStepKey: EnvironmentKey {
    static let defaultValue: PathStep? = nil
}

extension EnvironmentValues {
    /// The step the screen on show belongs to. The Music tab sets it for each
    /// step's screen, and the bottom action bar reads it to show the step bar.
    var currentPathStep: PathStep? {
        get { self[CurrentPathStepKey.self] }
        set { self[CurrentPathStepKey.self] = newValue }
    }
}

/// The top of every step's screen: which level this is, the step's title and
/// a plain line about what to do.
struct StepHeader: View {
    let step: PathStep
    /// Defaults to the step's own title.
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

/// "‹  Step 1 of 6  Listen & match ›": back to the previous step of the level
/// or on to the next. The arrows fade at the first and last step. It sits at
/// the bottom of a step's screen, just above the main button.
struct StepBar: View {
    let position: StepPosition
    @Environment(\.openPathStep) private var open
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 8) {
            arrow(to: position.previous, symbol: "chevron.left", name: "Previous step",
                  identifier: "previousStepButton")
            Text(position.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("stepPosition")
            Spacer(minLength: 4)
            if let next = position.next {
                Text(next.title).font(.caption.weight(.medium)).foregroundStyle(Palette.forest)
                    .lineLimit(1).accessibilityHidden(true)
            }
            arrow(to: position.next, symbol: "chevron.right", name: "Next step", identifier: "nextStepButton")
        }.padding(.horizontal, 6)
            .background(Palette.forest.opacity(0.06), in: RoundedRectangle(cornerRadius: Layout.tileRadius))
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func arrow(to step: PathStep?, symbol: String, name: String, identifier: String) -> some View {
        Button { if let step { open?(step) } } label: {
            Image(systemName: symbol).font(.footnote.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Palette.forest)
            .disabled(step == nil || open == nil).opacity(step == nil ? 0.25 : 1)
            .accessibilityLabel(step.map { "\(name), \($0.title)" } ?? name)
            .accessibilityIdentifier(identifier)
    }
}
