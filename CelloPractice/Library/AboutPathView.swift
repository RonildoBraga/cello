import SwiftUI

/// Where the path is heading, further reading and the recording credits.
/// It sits behind the info button so the path itself holds only levels.
struct AboutPathView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: "About this path", titleIdentifier: "aboutTitle")
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Where this is heading")
                    Text("Bach’s Cello Suite No. 1 is the long-term goal. Each level builds the listening, rhythm and note skills it needs; more melodies will join the path on the way there.")
                        .font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                }.card().accessibilityElement(children: .combine).accessibilityIdentifier("pathDestinationNote")
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Resources")
                    Link("ABRSM · Listening and aural skills", destination: URL(string: "https://teacherhub.abrsm.org/mod/page/view.php?id=2020")!)
                    Link("Royal Conservatory · Ear training", destination: URL(string: "https://www.rcmusic.com/learning/digital-learning/rcm-online-ear-training-rcm-online-sight-reading/ear-training")!)
                    Link("Frimley Health · Gentle humming", destination: URL(string: "https://www.fhft.nhs.uk/patients-and-visitors/patient-information-library/oral-resonance-bringing-voice-forward")!)
                }.font(.footnote).card()
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Recording credit")
                    Link("Deep Humming Noise · retropttam", destination: HummingExample.sourceURL)
                    Link("Creative Commons Attribution 3.0", destination: HummingExample.licenseURL)
                    Text("Foundation example: shortened and volume adjusted, with original pitch preserved. Melody examples: pitch and timing edited from the same human recording.")
                        .foregroundStyle(Palette.muted)
                    Divider()
                    Link("VSCO 2 Community Edition · recorded cello", destination: URL(string: "https://github.com/sgossner/VSCO-2-CE")!)
                    Link("Creative Commons CC0 1.0", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
                    Text("Bowed cello-section excerpts from Versilian Studios and Ivy Audio, shortened, volume adjusted and tuned for reference playback.")
                        .foregroundStyle(Palette.muted)
                }.font(.footnote).card()
            }.screenContent()
        }.background(Palette.paper).tint(Palette.forest)
            .bottomActionBar {
                Button("Done") { dismiss() }.buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("aboutDoneButton")
            }
    }
}
