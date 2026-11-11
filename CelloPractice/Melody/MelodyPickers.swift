import SwiftUI

/// Chooses one item from a short list, such as a phrase or a note, marking the
/// ones already completed.
struct ChoiceMenu<Choice: Hashable>: View {
    let choices: [Choice]
    @Binding var selection: Choice
    /// Spoken before the selected title: "Section: Phrase 1".
    var name = "Section"
    let title: (Choice) -> String
    var isCompleted: (Choice) -> Bool = { _ in false }

    var body: some View {
        Menu {
            ForEach(choices, id: \.self) { item in
                Button { selection = item } label: {
                    if isCompleted(item) {
                        Label("\(title(item)) · completed", systemImage: "checkmark.circle.fill")
                    } else if item == selection {
                        Label(title(item), systemImage: "checkmark")
                    } else {
                        Text(title(item))
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(title(selection)).font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }.foregroundStyle(Palette.forest).frame(minHeight: 44)
        }.accessibilityLabel("\(name): \(title(selection))")
    }
}
