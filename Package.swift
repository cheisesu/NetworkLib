// swift-tools-version: 6.0

import PackageDescription

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
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.0")
    ],
    targets: [
        .target(
            name: "NetworkLib",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
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
