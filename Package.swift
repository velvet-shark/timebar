// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Timebar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Timebar", targets: ["Timebar"])],
    targets: [
        .target(name: "TimebarCore"),
        .executableTarget(name: "Timebar", dependencies: ["TimebarCore"]),
        .testTarget(name: "TimebarCoreTests", dependencies: ["TimebarCore"]),
    ]
)
