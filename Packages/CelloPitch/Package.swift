// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CelloPitch",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "CelloPitch", targets: ["CelloPitch"])],
    targets: [
        .target(name: "CelloPitch"),
        // Re-scores saved takes with this checkout's rater; see Sources/cello-rescore/main.swift.
        .executableTarget(name: "cello-rescore", dependencies: ["CelloPitch"]),
        .testTarget(name: "CelloPitchTests", dependencies: ["CelloPitch"])
    ]
)
