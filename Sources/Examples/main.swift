import Darwin
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    guard let command = arguments.first else {
        ExampleCLI.printHelp()
        exit(0)
    }
    if command == "--help" || command == "-h" {
        ExampleCLI.printHelp()
        exit(0)
    }
    guard arguments.count == 1 else {
        throw ExampleError.message("Pass one example name. Use --help for instructions.")
    }
    switch command {
    case "async": try await SendingAndReceivingExample.run()
    case "callbacks": try await CallbackExample.run()
    case "proxy": try await ProxyExample.run()
    case "udp": try await TypedMessagesExample.run()
    case "headers": try HTTPHeadersExample.run()
    default: throw ExampleError.message("Unknown example '\(command)'. Use --help to list examples.")
    }
    ExampleCLI.log("Completed successfully.")
} catch {
    let message = "[error] \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(1)
}
