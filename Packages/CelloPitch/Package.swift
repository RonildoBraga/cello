// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CelloPitch",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "CelloPitch", targets: ["CelloPitch"])],
    targets: [
        .target(name: "CelloPitch"),
        .testTarget(name: "CelloPitchTests", dependencies: ["CelloPitch"])
    ]
)
