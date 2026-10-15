import Foundation
import PackagePlugin

@main
struct NWSwiftLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
        guard target is SourceModuleTarget else { return [] }
        var commands: [Command] = [
            try createCommand("", config: ".swiftlint.yml", context: context),
        ]
        let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
        if isCI {
            try commands.append(createCommand("Docs", config: ".swiftlint.docs.yml", context: context))
        }
        return commands
    }

    private func createCommand(_ phase: String, config: String, context: PluginContext) throws -> Command
    {
        let tool = swiftlintUrl(in: context)
        let names = ["SwiftLint", phase].filter { !$0.isEmpty }
        let displayName = names.joined(separator: " ")
        let dirPrefix = names.joined()
        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: dirPrefix)
        let cacheDirectory = context.pluginWorkDirectoryURL.appending(path: dirPrefix + "Cache")
        let packageDirectory = context.package.directoryURL.path()
        let configUrl = context.package.directoryURL.appending(component: config)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let arguments = [
            "lint",
            "--config",
            configUrl.path(),
            "--reporter",
            "xcode",
            "--cache-path",
            cacheDirectory.path(),
            packageDirectory,
        ]

        return .prebuildCommand(displayName: displayName, executable: tool, arguments: arguments,
                                outputFilesDirectory: outputDirectory)
    }

    private func swiftlintUrl(in context: PluginContext) -> URL {
        URL(filePath: "/opt/homebrew/bin/swiftlint")
    }
}
