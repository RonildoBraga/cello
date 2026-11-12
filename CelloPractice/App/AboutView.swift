import SwiftUI

/// The About tab: where the path is heading, who made the app, where every
/// sound comes from and what informed the lessons.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "About", subtitle: "Who made this, where the sounds come from, and where the path is heading.",
                             titleIdentifier: "aboutTitle")

                section("Where this is heading", identifier: "pathDestinationNote") {
                    note("Bach’s Cello Suite No. 1 is the long-term goal. Each level builds the listening, rhythm and note skills it needs; more melodies will join the path on the way there.")
                }

                section("Privacy & support", identifier: "aboutPrivacySupport") {
                    note("Your recordings, pitch data and progress are saved on your iPhone. Cello has no accounts, ads, analytics or automatic uploads.")
                    Link("Privacy policy", destination: URL(string: "https://ronildobraga.github.io/cello/privacy.html")!)
                        .frame(minHeight: 44).accessibilityIdentifier("aboutPrivacyLink")
                    Link("Help & support", destination: URL(string: "https://ronildobraga.github.io/cello/")!)
                        .frame(minHeight: 44).accessibilityIdentifier("aboutSupportLink")
                    Link("Email ronildo@blueberry.money", destination: URL(string: "mailto:ronildo@blueberry.money")!)
                        .frame(minHeight: 44).accessibilityIdentifier("aboutEmailLink")
                }

                section("Who built it", identifier: "aboutBuilders") {
                    credit("Ronildo Braga", "Idea, design, testing on a real iPhone and every decision about what the app should be.")
                    credit("Claude, by Anthropic", "AI assistant that wrote the code, lessons and tests with Ronildo.")
                    note("Built with Apple’s SwiftUI, AVFoundation and Swift Charts. No third-party code is included.")
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/RonildoBraga/cello")!)
                }

                section("The humming voice", identifier: "aboutHumming") {
                    credit("“Deep Humming Noise” by retropttam", "A real person humming a low note, shared on Freesound.")
                    Link("Original recording on Freesound", destination: HummingExample.sourceURL)
                    Link("Creative Commons Attribution 3.0", destination: HummingExample.licenseURL)
                    note("The first lessons play three seconds of it at its original pitch, shortened and made louder. For melodies, single notes and Listen & Echo the same recording is retuned and re-timed note by note. Those are edited recordings of a real voice, not a performance by the original author, and no endorsement by them is implied.")
                }

                section("The cello", identifier: "aboutCello") {
                    credit("VSCO 2 Community Edition", "Recorded by Sam Gossner and Simon Dalzell; samples cut by Elan Hickler (Soundemote). Versilian Studios and Ivy Audio.")
                    Link("VSCO 2 Community Edition", destination: URL(string: "https://github.com/sgossner/VSCO-2-CE")!)
                    Link("Creative Commons CC0 1.0", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
                    note("Bowed notes from a cello section, shortened, volume adjusted and tuned to each note. They show a cello’s pitch and tone, not how to play an open string.")
                }

                section("Everything else you hear and feel", identifier: "aboutOtherSounds") {
                    note("Nothing in the app is a computer-made tone: every example is one of the two recordings above. Rhythm lessons use your phone’s vibration and make no sound.")
                }

                section("The melodies", identifier: "aboutMelodies") {
                    note("Hot Cross Buns is a traditional tune. Ode to Joy is the opening of Beethoven’s theme. Twinkle, Twinkle, Little Star opens with the old French tune “Ah! vous dirai-je, maman”. Lightly Row is the old German tune of “Hänschen klein”. Old MacDonald is a traditional song. Yankee Doodle is an 18th-century tune. All six are our own short teaching arrangements. The G major scale is the key of Bach’s first Prelude.")
                }

                section("What informed the lessons", identifier: "aboutReferences") {
                    Link("ABRSM · Listening and aural skills", destination: URL(string: "https://teacherhub.abrsm.org/mod/page/view.php?id=2020")!)
                    Link("Royal Conservatory · Ear training", destination: URL(string: "https://www.rcmusic.com/learning/digital-learning/rcm-online-ear-training-rcm-online-sight-reading/ear-training")!)
                    Link("Frimley Health · Gentle humming", destination: URL(string: "https://www.fhft.nhs.uk/patients-and-visitors/patient-information-library/oral-resonance-bringing-voice-forward")!)
                    Link("MacEwan University · Clapping and counting basic rhythms", destination: URL(string: "https://openbooks.macewan.ca/introtoeartraining/chapter/clapping-and-counting-basic-rhythms/")!)
                    Link("Mel Bay · Modern Cello Method, contents", destination: URL(string: "https://www.melbay.com/Products/21499BCDEB/modern-cello-method-grade-1.aspx")!)
                    note("These shaped the order of the lessons. None of their scores, recordings or text is included.")
                }

                Text(Self.version).font(.caption).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .center).accessibilityIdentifier("aboutVersion")
            }.screenContent()
        }.background(Palette.paper).tint(Palette.forest)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Cello \(version) (\(build))"
    }

    private func section<Content: View>(_ title: String, identifier: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title)
            content()
        }.font(.footnote).card().accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }

    private func credit(_ name: String, _ role: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(role).font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
    }
}
