// swift-tools-version: 6.0

import PackageDescription
import Foundation

let package = Package(
    name: "NetworkLib",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "NetworkLib",
            targets: ["NetworkLib"]
        ),
        .plugin(name: "nl-swiftlint-plugin", targets: ["nl-swiftlint-plugin"]),
    ],
    targets: [
        .plugin(name: "nl-swiftlint-plugin", capability: .buildTool()),
        .target(
            name: "NetworkLib",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ],
            plugins: [.plugin(name: "nl-swiftlint-plugin")]
        ),
        .testTarget(
            name: "NetworkLibTests",
            dependencies: ["NetworkLib"],
            resources: [
                .copy("Resources/localhost.crt"),
                .copy("Resources/localhost.key"),
                .copy("Resources/localhost.p12"),
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
