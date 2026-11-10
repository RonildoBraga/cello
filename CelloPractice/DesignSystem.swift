import SwiftUI

enum Palette {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let forest = Color(red: 0.16, green: 0.30, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.20, blue: 0.18)
    static let gold = Color(red: 0.69, green: 0.47, blue: 0.24)
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.41)
}

func timeString(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(exactly: duration.rounded(.towardZero)) ?? 0)
    let remainder = seconds % 60
    return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
}
