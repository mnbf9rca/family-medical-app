// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpaqueSwift",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "OpaqueSwift", targets: ["OpaqueSwift", "OpaqueSwiftFFI"])
    ],
    targets: [
        .target(
            name: "OpaqueSwift",
            dependencies: ["OpaqueSwiftFFI"],
            path: "generated",
            sources: ["opaque_swift.swift"]
        ),
        .binaryTarget(
            name: "OpaqueSwiftFFI",
            path: "OpaqueSwift.xcframework"
        )
    ]
)
