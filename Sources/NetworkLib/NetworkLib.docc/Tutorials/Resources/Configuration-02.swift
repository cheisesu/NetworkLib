import NetworkLib

func makeConfiguration() -> RawSocketConfiguration {
    RawSocketConfiguration(
        "example.com",
        .https,
        ipVersion: .any,
        isSecure: true,
        sni: "example.com",
        transport: .tcp,
        maxDataBlock: 16 * 1024,
        timeout: 15
    )
}
