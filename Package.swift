// swift-tools-version: 6.0

import PackageDescription
import Foundation

private let commonSettings: [SwiftSetting]? = [
    .unsafeFlags(["-warnings-as-errors"]),
]

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
        // MARK: PLUGINS
        .plugin(name: "nl-swiftlint-plugin", capability: .buildTool()),
        // MARK: LIB TARGETS
        .target(
            name: "NetworkLib",
            swiftSettings: commonSettings,
            plugins: [.plugin(name: "nl-swiftlint-plugin")]
        ),
        // MARK: TEST TARGETS
        .testTarget(
            name: "NetworkLibTests",
            dependencies: ["NetworkLib"],
            resources: [
                .copy("Resources/localhost.crt"),
                .copy("Resources/localhost.key"),
                .copy("Resources/localhost.p12"),
            ],
            swiftSettings: commonSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
