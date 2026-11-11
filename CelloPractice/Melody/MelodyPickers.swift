import SwiftUI

/// The parts of a lesson side by side, such as its phrases or notes: which one
/// is on show, which are passed or gold, and a tap to switch. It replaces a
/// drop-down menu, which hid the other parts and how far each had got.
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
        return Button { selection = part } label: {
            HStack(spacing: 4) {
                if let result {
                    Image(systemName: result == "gold" ? "star.fill" : "checkmark").font(.caption2.weight(.bold))
                        .foregroundStyle(selected ? .white : result == "gold" ? Palette.goldText : Palette.forest)
                }
                Text(short(part))
            }.font(.subheadline.weight(.semibold)).foregroundStyle(selected ? .white : Palette.forest)
                .padding(.horizontal, 13).frame(minWidth: 44, minHeight: 44)
                .background(selected ? Palette.forest : Palette.forest.opacity(0.07), in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityLabel([title(part), result].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("part-\(title(part))")
    }
}

extension MelodySection {
    /// On a chip: the phrase number, or "All" for the whole melody.
    var chipLabel: String { self == .whole ? "All" : String(title.suffix(1)) }
}
