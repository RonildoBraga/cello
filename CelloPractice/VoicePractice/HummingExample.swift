import Foundation

/// A short excerpt of a human recording, kept at its original pitch.
enum HummingExample {
    // Median of the bundled excerpt, measured with the app's pitch detector.
    static let frequency = 110.64730204182847
    static let duration = 3.0
    static let sourceURL = URL(string: "https://freesound.org/people/retropttam/sounds/177276/")!
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/3.0/")!

    static func wavData() throws -> Data {
        guard let url = Bundle.main.url(forResource: "hum-example", withExtension: "wav") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
