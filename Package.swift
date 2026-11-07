// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "HeadlessMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HeadlessMac", targets: ["HeadlessMac"])],
    targets: [
        .executableTarget(name: "HeadlessMac", linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("IOKit")]),
        .testTarget(name: "HeadlessMacTests", dependencies: ["HeadlessMac"])
    ],
    swiftLanguageModes: [.v5]
)
