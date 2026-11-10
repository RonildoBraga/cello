import SwiftUI

/// Chooses a phrase or the whole melody, marking the phrases already completed.
struct SectionMenu: View {
    @Binding var selection: MelodySection
    var isCompleted: (MelodySection) -> Bool = { _ in false }

    var body: some View {
        Menu {
            ForEach(MelodySection.allCases) { item in
                Button { selection = item } label: {
                    if isCompleted(item) {
                        Label("\(item.title) · completed", systemImage: "checkmark.circle.fill")
                    } else if item == selection {
                        Label(item.title, systemImage: "checkmark")
                    } else {
                        Text(item.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(selection.title).font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }.foregroundStyle(Palette.forest).frame(minHeight: 44)
        }.accessibilityLabel("Section: \(selection.title)")
    }
}
