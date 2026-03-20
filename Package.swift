// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "XeeLite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "XeeLite",
            targets: ["XeeLite"]
        )
    ],
    targets: [
        .executableTarget(
            name: "XeeLite"
        )
    ]
)
