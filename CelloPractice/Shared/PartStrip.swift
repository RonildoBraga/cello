import SwiftUI

/// How a lesson's chips play what they name.
struct PartHearing {
    /// What the chip on show is called when spoken: "Hear note, Reference G2".
    let spoken: String
    /// The identifier the chip on show takes.
    let identifier: String
    /// Runs after a tap; `changed` is true when the tap switched to another part.
    let action: (_ changed: Bool) -> Void
}

/// The parts of a lesson side by side, such as its phrases or notes: which one
/// is on show, which are passed or gold, and a tap to switch. Where a part can
/// be heard, tapping its chip plays it: the
/// chip on show carries a speaker and plays again when tapped. A lesson with one
/// part shows one chip.
struct PartStrip<Part: Hashable>: View {
    let parts: [Part]
    @Binding var selection: Part
    /// A word before the chips when they are only numbers: "Phrase".
    var leading: String? = nil
    /// The few characters on the chip.
    let short: (Part) -> String
    /// The full name, spoken and used to find the chip.
    let title: (Part) -> String
    var progress: (Part) -> PracticeProgress? = { _ in nil }
    /// Set where chips play: what the chip on show is called when spoken, the
    /// identifier it takes, and what a tap on any chip does after selecting it.
    var hear: PartHearing? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let leading {
                    Text(leading).font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
                ForEach(parts, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ part: Part) -> some View {
        let selected = part == selection
        let progress = progress(part)
        let result = progress?.completed == true ? "gold" : progress?.passed == true ? "passed" : nil
        return Button {
            let changed = part != selection
            selection = part
            hear?.action(changed)
        } label: {
            HStack(spacing: 4) {
                if selected, hear != nil {
                    Image(systemName: "speaker.wave.2.fill").font(.caption2)
                } else if let result {
                    Image(systemName: result == "gold" ? "star.fill" : "checkmark").font(.caption2.weight(.bold))
                        .foregroundStyle(selected ? .white : result == "gold" ? Palette.goldText : Palette.forest)
                }
                Text(short(part))
            }.font(.subheadline.weight(.semibold)).foregroundStyle(selected ? .white : Palette.forest)
                .padding(.horizontal, 13).frame(minWidth: 44, minHeight: 44)
                .background(selected ? Palette.forest : Palette.forest.opacity(0.07), in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityLabel([title(part), result, selected ? hear?.spoken : nil].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(selected ? hear?.identifier ?? "part-\(title(part))" : "part-\(title(part))")
    }
}
