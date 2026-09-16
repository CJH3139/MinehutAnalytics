// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MinehutKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "MinehutKit", targets: ["MinehutKit"]),
    ],
    targets: [
        .target(name: "MinehutKit"),
        .testTarget(name: "MinehutKitTests", dependencies: ["MinehutKit"]),
    ],
    swiftLanguageModes: [.v5]
)
