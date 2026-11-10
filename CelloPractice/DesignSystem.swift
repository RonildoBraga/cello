import SwiftUI

/// The app's shared look: colours, spacing, and the handful of components every
/// screen is built from. Feature views use these instead of inline radii,
/// paddings and font sizes.
enum Palette {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let forest = Color(red: 0.16, green: 0.30, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.20, blue: 0.18)
    static let gold = Color(red: 0.69, green: 0.47, blue: 0.24)
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.41)
}

enum Layout {
    /// Horizontal screen margin.
    static let gutter: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let cardRadius: CGFloat = 20
    /// Buttons, tap pads and other large controls.
    static let controlRadius: CGFloat = 16
    /// Icon tiles and small chips.
    static let tileRadius: CGFloat = 12
    static let tileSize: CGFloat = 44
}

extension Font {
    static let screenTitle = Font.system(.title, design: .serif).weight(.semibold)
    static let eyebrow = Font.system(.caption2, design: .rounded).weight(.bold)
    /// Countdown digits and one-word states on the dark status cards.
    static let statusValue = Font.system(size: 46, weight: .light, design: .rounded)
    static let statusCount = Font.system(size: 62, weight: .light, design: .rounded)
}

extension View {
    /// The white content card.
    func card(padding: CGFloat = Layout.cardPadding) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
    }

    /// Margins for a screen's scrolling content.
    func screenContent() -> some View {
        padding(.horizontal, Layout.gutter).padding(.top, 16).padding(.bottom, 24)
    }

    /// Names the screen for the back stack and assistive technology without
    /// drawing it in the bar: each screen shows its title once, in `ScreenHeader`.
    func screenTitle(_ title: String) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
            }
    }

    /// Pins a screen's primary action above the tab bar.
    func bottomActionBar<Bar: View>(@ViewBuilder _ bar: @escaping () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) { bar() }
                .padding(.horizontal, Layout.gutter).padding(.vertical, 12)
                .frame(maxWidth: .infinity).background(Palette.paper)
        }
    }
}

/// Small upper-case label above a title or on a card. The spoken label keeps the
/// original casing.
struct Eyebrow: View {
    let text: String
    var color = Palette.muted

    var body: some View {
        Text(text).font(.eyebrow).tracking(1.5).textCase(.uppercase)
            .foregroundStyle(color).accessibilityLabel(text)
    }
}

/// The one place a screen shows its title.
struct ScreenHeader: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var titleIdentifier = "screenTitle"
    var eyebrowIdentifier = "screenEyebrow"
    var subtitleIdentifier = "screenSubtitle"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Eyebrow(text: eyebrow, color: Palette.gold).accessibilityIdentifier(eyebrowIdentifier)
            }
            Text(title).font(.screenTitle).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier(titleIdentifier)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(subtitleIdentifier)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Heading for a group of cards or rows inside a screen.
struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.headline).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
    }
}

/// The full-width action at the bottom of a screen.
struct PrimaryActionButtonStyle: ButtonStyle {
    var color = Palette.forest
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(color, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.55)
    }
}

/// A quiet inline action, such as Hear phrase or New pattern.
struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
            .frame(minHeight: 44).padding(.horizontal, 14)
            .background(Palette.forest.opacity(0.06), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

/// A navigable row in the library: icon or lesson number, title, subtitle, and
/// either a footer line or a custom status line.
struct LibraryRow<Status: View>: View {
    enum Leading {
        case symbol(String)
        case number(Int)
    }

    let leading: Leading
    let title: String
    let subtitle: String
    var footer: String? = nil
    @ViewBuilder var status: Status

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Group {
                    switch leading {
                    case .symbol(let name): Image(systemName: name).font(.title3)
                    case .number(let number):
                        Text(String(format: "%02d", number)).font(.system(.title3, design: .serif).weight(.semibold))
                    }
                }.foregroundStyle(Palette.forest)
                    .frame(width: Layout.tileSize, height: Layout.tileSize)
                    .background(Palette.forest.opacity(0.07), in: RoundedRectangle(cornerRadius: Layout.tileRadius))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).foregroundStyle(Palette.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(Palette.muted)
                    if let footer { Text(footer).font(.caption).foregroundStyle(Palette.forest) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
            }
            status
        }.card().contentShape(Rectangle())
    }
}

extension LibraryRow where Status == EmptyView {
    init(symbol: String, title: String, subtitle: String, footer: String? = nil) {
        self.init(leading: .symbol(symbol), title: title, subtitle: subtitle, footer: footer) { EmptyView() }
    }
}

/// A score out of three.
struct Stars: View {
    let count: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .foregroundStyle(index < count ? Palette.gold : Palette.muted.opacity(0.45))
            }
        }.font(.system(size: size, weight: .medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) of 3 stars")
    }
}

/// One numbered line in a list of instructions or milestones.
struct NumberedStep: View {
    let number: Int
    var title: String? = nil
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                .frame(width: 24, height: 24)
                .background(Palette.forest.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                if let title { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink) }
                Text(detail).font(title == nil ? .subheadline : .footnote).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The dark card that shows what is happening now: tuner, countdown or beat.
struct StatusCard<Trailing: View, Content: View>: View {
    let label: String
    var labelIdentifier = "statusLabel"
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Eyebrow(text: label, color: .white.opacity(0.7)).accessibilityIdentifier(labelIdentifier)
                Spacer()
                trailing.font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            content
        }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity)
            .background(Palette.forest, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
    }
}

func timeString(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(exactly: duration.rounded(.towardZero)) ?? 0)
    let remainder = seconds % 60
    return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
}
