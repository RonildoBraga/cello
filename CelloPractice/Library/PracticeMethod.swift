import SwiftUI

/// How a recorded lesson is practised. The lesson and its goals stay the same;
/// the sound to match, the instructions and what is recorded follow the method.
/// Progress is kept for each method, and either one passes the lesson.
enum PracticeMethod: String, CaseIterable, Identifiable {
    case voice, cello

    /// The cello's side of a single-note lesson: the four open strings, low to high.
    static let openStrings: [Exercise] = [.openC, .openG, .openD, .openA]

    var id: String { rawValue }
    var title: String { self == .voice ? "Voice" : "Cello" }
    /// The register a melody, its notes or an echo pattern is practised in.
    var register: MelodyRegister { self == .voice ? .lowVoice : .cello }
    /// "hum" or "play", for instructions.
    var verb: String { self == .voice ? "hum" : "play" }
}

extension PracticeMethod {
    /// How a take of this exercise, or of this melody, is made.
    init(exercise: Exercise, melody: MelodyPracticeContext?) {
        self = exercise.method == .cello || melody?.register == .cello ? .cello : .voice
    }
}

private struct PracticeMethodKey: EnvironmentKey {
    static let defaultValue: Binding<PracticeMethod> = .constant(.voice)
}

extension EnvironmentValues {
    /// The method on show in every recorded lesson, and how to change it. The Music
    /// tab provides it: lessons open the way the last take was made.
    var practiceMethod: Binding<PracticeMethod> {
        get { self[PracticeMethodKey.self] }
        set { self[PracticeMethodKey.self] = newValue }
    }
}

/// Voice or cello, in the bar of every lesson that has a sound to hear or record.
/// The cello is filmed and the voice is not, so changing method releases the
/// microphone and camera, and stops whatever is playing. The switch follows only
/// whether a take is recording, never the controller's ticks.
struct PracticeMethodSwitch: View {
    let capture: CaptureController
    @Environment(\.practiceMethod) private var method
    @State private var recording = false

    var body: some View {
        Picker("Practise with", selection: Binding(get: { method.wrappedValue }, set: { next in
            if next != method.wrappedValue { capture.stop() }
            method.wrappedValue = next
        })) {
            ForEach(PracticeMethod.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).frame(width: 150).disabled(recording)
            .accessibilityIdentifier("practiceMethodPicker")
            .onReceive(capture.$isRecording) { recording = $0 }
    }
}
