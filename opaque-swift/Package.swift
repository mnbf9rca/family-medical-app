// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpaqueSwift",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "OpaqueSwift", targets: ["OpaqueSwift"])
    ],
    targets: [
        .target(
            name: "OpaqueSwift",
            dependencies: ["OpaqueSwiftFFI", "opaque_swift"],
            path: "Sources/OpaqueSwift"
        ),
        .target(
            name: "OpaqueSwiftFFI",
            path: "Sources/OpaqueSwiftFFI",
            publicHeadersPath: "."
        ),
        .binaryTarget(
            name: "opaque_swift",
            path: "OpaqueSwift.xcframework"
        )
    ]
)
