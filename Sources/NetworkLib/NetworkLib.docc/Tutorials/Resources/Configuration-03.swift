import Network
import NetworkLib

func makeConfiguration(interface: NWInterface) -> RawSocketConfiguration {
    RawSocketConfiguration(
        "example.com",
        .https,
        ipVersion: .any,
        isSecure: true,
        sni: "example.com",
        transport: .tcp,
        maxDataBlock: 16 * 1024,
        timeout: 15,
        interface: interface
    )
}

func makeConfiguration(path: NWPath, interfaceName: String) throws -> RawSocketConfiguration {
    guard let interface = path.availableInterfaces.first(where: { $0.name == interfaceName }) else {
        throw NWError.posix(.ENODEV)
    }
    return makeConfiguration(interface: interface)
}
