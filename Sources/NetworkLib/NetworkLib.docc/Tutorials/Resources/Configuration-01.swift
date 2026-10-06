import NetworkLib

func makeConfiguration() -> RawSocketConfiguration {
    RawSocketConfiguration("example.com", .https)
}
