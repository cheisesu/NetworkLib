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
        .library(name: "NetworkLibCore", targets: ["NetworkLibCore"]),
        .library(name: "NetworkLibHttpCore", targets: ["NetworkLibHttpCore"]),
        .library(name: "NetworkLibUtils", targets: ["NetworkLibUtils"]),
        .plugin(name: "nl-swiftlint-plugin", targets: ["nl-swiftlint-plugin"]),
    ],
    targets: [
        // MARK: PLUGINS
        .plugin(name: "nl-swiftlint-plugin", capability: .buildTool()),
        // MARK: LIB TARGETS
        .target(
            name: "NetworkLibCore",
            dependencies: ["NetworkLibUtils", "NetworkLibHttpCore"],
            exclude: ["Proxy/ProtocolProxy.swift"],
            swiftSettings: commonSettings,
            plugins: [.plugin(name: "nl-swiftlint-plugin")]
        ),
        .target(
            name: "NetworkLibHttpCore",
            dependencies: ["NetworkLibUtils"],
            swiftSettings: commonSettings,
            plugins: [.plugin(name: "nl-swiftlint-plugin")]
        ),
        .target(
            name: "NetworkLibUtils",
            swiftSettings: commonSettings,
            plugins: [.plugin(name: "nl-swiftlint-plugin")]
        ),
        // MARK: TEST TARGETS
        .testTarget(
            name: "NetworkLibCoreTests",
            dependencies: ["NetworkLibCore", "NetworkLibHttpCore"],
//            resources: [
//                .copy("Resources/localhost.crt"),
//                .copy("Resources/localhost.key"),
//                .copy("Resources/localhost.p12"),
//            ],
            swiftSettings: commonSettings
        ),
        .testTarget(
            name: "NetworkLibHttpCoreTests",
            dependencies: ["NetworkLibHttpCore", "NetworkLibUtils"],
            swiftSettings: commonSettings
        ),
        .testTarget(
            name: "NetworkLibUtilsTests",
            dependencies: ["NetworkLibCore", "NetworkLibUtils"],
            swiftSettings: commonSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
