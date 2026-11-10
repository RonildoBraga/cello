import SwiftUI

/// Original front-view illustration. Callouts remain native, accessible text.
struct CelloDiagramView: View {
    private struct Callout: Identifiable {
        let title: String
        let detail: String
        let left: Bool
        let y: CGFloat
        let target: CGPoint
        var id: String { title }
    }

    private let callouts = [
        Callout(title: "Scroll", detail: "The curled top of the cello.", left: true,
                y: 25, target: CGPoint(x: 156, y: 25)),
        Callout(title: "Pegs", detail: "Hold the strings and adjust their tuning.", left: false,
                y: 72, target: CGPoint(x: 188, y: 72)),
        Callout(title: "Fingerboard", detail: "The dark surface beneath the strings.", left: true,
                y: 139, target: CGPoint(x: 161, y: 139)),
        Callout(title: "Strings", detail: "Four strings vibrate to make sound.", left: false,
                y: 191, target: CGPoint(x: 180, y: 191)),
        Callout(title: "f-holes", detail: "The two curved openings in the body.", left: true,
                y: 253, target: CGPoint(x: 141, y: 253)),
        Callout(title: "Bridge", detail: "Supports the strings above the body.", left: false,
                y: 287, target: CGPoint(x: 185, y: 286)),
        Callout(title: "Tailpiece", detail: "Anchors the strings near the bottom of the body.", left: true,
                y: 341, target: CGPoint(x: 165, y: 341)),
        Callout(title: "Endpin", detail: "Extends from the bottom to support the cello on the floor.", left: false,
                y: 420, target: CGPoint(x: 170, y: 420))
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    context.scaleBy(x: size.width / 340, y: size.height / 450)
                    drawCello(in: &context)
                    for item in callouts {
                        var line = Path()
                        line.move(to: CGPoint(x: item.left ? 87 : 253, y: item.y))
                        line.addLine(to: CGPoint(x: item.left ? 97 : 243, y: item.y))
                        line.addLine(to: item.target)
                        context.stroke(line, with: .color(Palette.muted.opacity(0.55)), lineWidth: 0.8)
                        context.fill(Path(ellipseIn: CGRect(x: item.target.x - 2, y: item.target.y - 2,
                                                            width: 4, height: 4)),
                                     with: .color(Palette.forest))
                    }
                }.accessibilityHidden(true)
                ForEach(callouts) { item in
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.9)
                        .frame(width: geometry.size.width * 0.25,
                               alignment: item.left ? .leading : .trailing)
                        .position(x: geometry.size.width * (item.left ? 0.125 : 0.875),
                                  y: geometry.size.height * item.y / 450)
                        .accessibilityLabel("\(item.title). \(item.detail)")
                }
            }
        }.aspectRatio(340.0 / 450, contentMode: .fit)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cello parts, viewed from the front: scroll, pegs, fingerboard, strings, f-holes, bridge, tailpiece and endpin")
            .accessibilityIdentifier("celloPartsDiagram")
    }

    private func drawCello(in context: inout GraphicsContext) {
        let wood = Color(red: 0.67, green: 0.38, blue: 0.18)
        let darkWood = Color(red: 0.38, green: 0.21, blue: 0.12)
        let ebony = Color(red: 0.20, green: 0.23, blue: 0.21)
        let body = celloBody()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [wood.opacity(0.82), wood, Palette.gold.opacity(0.88)]),
            startPoint: CGPoint(x: 104, y: 220), endPoint: CGPoint(x: 239, y: 351)))
        context.stroke(body, with: .color(darkWood.opacity(0.75)), lineWidth: 1.7)
        context.stroke(body.applying(CGAffineTransform(a: 0.94, b: 0, c: 0, d: 0.96, tx: 10.2, ty: 11.04)),
            with: .color(Color.white.opacity(0.32)), lineWidth: 0.8)

        // The neck, pegbox and scroll sit behind the fingerboard.
        var neck = Path()
        neck.move(to: CGPoint(x: 160, y: 38))
        neck.addLine(to: CGPoint(x: 180, y: 38))
        neck.addLine(to: CGPoint(x: 181, y: 178))
        neck.addLine(to: CGPoint(x: 159, y: 178))
        neck.closeSubpath()
        context.fill(neck, with: .color(wood))
        context.stroke(neck, with: .color(darkWood), lineWidth: 1)
        context.fill(Path(roundedRect: CGRect(x: 165, y: 46, width: 10, height: 48), cornerRadius: 4),
                     with: .color(ebony))
        for (x, y) in [(150.0, 57.0), (190, 70), (150, 82), (190, 95)] {
            let left = x < 170
            var shaft = Path()
            shaft.move(to: CGPoint(x: left ? 153 : 179, y: y))
            shaft.addLine(to: CGPoint(x: left ? 161 : 187, y: y))
            context.stroke(shaft, with: .color(darkWood), lineWidth: 3)
            context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 5, width: 8, height: 10)),
                         with: .color(ebony))
        }
        let scroll = Path(ellipseIn: CGRect(x: 156, y: 11, width: 28, height: 31))
        context.fill(scroll, with: .color(wood))
        context.stroke(scroll, with: .color(darkWood), lineWidth: 1.3)
        var curl = Path()
        curl.move(to: CGPoint(x: 171, y: 36))
        curl.addCurve(to: CGPoint(x: 179, y: 21), control1: CGPoint(x: 183, y: 35), control2: CGPoint(x: 184, y: 22))
        curl.addCurve(to: CGPoint(x: 162, y: 25), control1: CGPoint(x: 173, y: 13), control2: CGPoint(x: 159, y: 17))
        curl.addCurve(to: CGPoint(x: 173, y: 28), control1: CGPoint(x: 163, y: 33), control2: CGPoint(x: 177, y: 33))
        context.stroke(curl, with: .color(darkWood), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        var fingerboard = Path()
        fingerboard.move(to: CGPoint(x: 163, y: 96))
        fingerboard.addLine(to: CGPoint(x: 177, y: 96))
        fingerboard.addLine(to: CGPoint(x: 185, y: 257))
        fingerboard.addQuadCurve(to: CGPoint(x: 155, y: 257), control: CGPoint(x: 170, y: 262))
        fingerboard.closeSubpath()
        context.fill(fingerboard, with: .color(ebony))

        let fHole = soundHole()
        context.stroke(fHole, with: .color(darkWood), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        context.stroke(fHole.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 340, ty: 0)),
                       with: .color(darkWood), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

        var tailpiece = Path()
        tailpiece.move(to: CGPoint(x: 158, y: 303))
        tailpiece.addQuadCurve(to: CGPoint(x: 182, y: 303), control: CGPoint(x: 170, y: 299))
        tailpiece.addLine(to: CGPoint(x: 174, y: 364))
        tailpiece.addQuadCurve(to: CGPoint(x: 166, y: 364), control: CGPoint(x: 170, y: 372))
        tailpiece.closeSubpath()
        context.fill(tailpiece, with: .color(ebony))
        for index in 0..<4 {
            var string = Path()
            string.move(to: CGPoint(x: 165.5 + Double(index) * 3, y: 96))
            string.addLine(to: CGPoint(x: 158 + Double(index) * 8, y: 281))
            string.addLine(to: CGPoint(x: 163.5 + Double(index) * 4.3, y: 308))
            context.stroke(string, with: .color(Color(red: 0.92, green: 0.85, blue: 0.65)),
                           lineWidth: 0.9 - Double(index) * 0.12)
        }
        // A lightly arched bridge crosses the strings between the f-holes.
        var bridge = Path()
        bridge.move(to: CGPoint(x: 148, y: 286))
        bridge.addQuadCurve(to: CGPoint(x: 192, y: 286), control: CGPoint(x: 170, y: 272))
        bridge.addLine(to: CGPoint(x: 190, y: 292))
        bridge.addQuadCurve(to: CGPoint(x: 150, y: 292), control: CGPoint(x: 170, y: 284))
        bridge.closeSubpath()
        context.fill(bridge, with: .color(Color(red: 0.88, green: 0.73, blue: 0.49)))
        context.stroke(bridge, with: .color(darkWood.opacity(0.75)), lineWidth: 0.8)

        var endpin = Path()
        endpin.move(to: CGPoint(x: 170, y: 389))
        endpin.addLine(to: CGPoint(x: 170, y: 440))
        context.stroke(endpin, with: .color(Palette.muted), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 166, y: 437, width: 8, height: 5)), with: .color(ebony))
    }

    private func celloBody() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 170, y: 166))
        path.addCurve(to: CGPoint(x: 112, y: 202), control1: CGPoint(x: 131, y: 156), control2: CGPoint(x: 111, y: 174))
        path.addQuadCurve(to: CGPoint(x: 121, y: 225), control: CGPoint(x: 110, y: 215))
        path.addLine(to: CGPoint(x: 130, y: 226))
        path.addCurve(to: CGPoint(x: 126, y: 272), control1: CGPoint(x: 140, y: 242), control2: CGPoint(x: 140, y: 258))
        path.addLine(to: CGPoint(x: 115, y: 274))
        path.addLine(to: CGPoint(x: 119, y: 282))
        path.addCurve(to: CGPoint(x: 96, y: 334), control1: CGPoint(x: 97, y: 296), control2: CGPoint(x: 93, y: 314))
        path.addCurve(to: CGPoint(x: 170, y: 391), control1: CGPoint(x: 98, y: 376), control2: CGPoint(x: 124, y: 396))
        path.addCurve(to: CGPoint(x: 244, y: 334), control1: CGPoint(x: 216, y: 396), control2: CGPoint(x: 242, y: 376))
        path.addCurve(to: CGPoint(x: 221, y: 282), control1: CGPoint(x: 247, y: 314), control2: CGPoint(x: 243, y: 296))
        path.addLine(to: CGPoint(x: 225, y: 274))
        path.addLine(to: CGPoint(x: 214, y: 272))
        path.addCurve(to: CGPoint(x: 210, y: 226), control1: CGPoint(x: 200, y: 258), control2: CGPoint(x: 200, y: 242))
        path.addLine(to: CGPoint(x: 219, y: 225))
        path.addQuadCurve(to: CGPoint(x: 228, y: 202), control: CGPoint(x: 230, y: 215))
        path.addCurve(to: CGPoint(x: 170, y: 166), control1: CGPoint(x: 229, y: 174), control2: CGPoint(x: 209, y: 156))
        path.closeSubpath()
        return path
    }

    private func soundHole() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 147, y: 237))
        path.addCurve(to: CGPoint(x: 142, y: 262), control1: CGPoint(x: 155, y: 238), control2: CGPoint(x: 144, y: 250))
        path.addCurve(to: CGPoint(x: 138, y: 289), control1: CGPoint(x: 140, y: 273), control2: CGPoint(x: 133, y: 289))
        path.addQuadCurve(to: CGPoint(x: 144, y: 285), control: CGPoint(x: 144, y: 291))
        path.move(to: CGPoint(x: 136, y: 262))
        path.addLine(to: CGPoint(x: 147, y: 262))
        return path
    }
}
