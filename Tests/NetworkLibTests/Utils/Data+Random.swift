import Foundation

extension Data {
    static func random(of size: Int) -> Data {
        let array = (0..<size).map { _ in UInt8.random(in: 0..<UInt8.max) }
        let data = Data(array)
        return data
    }

    func byChunks(of chunkSize: Int) -> [Data] {
        stride(from: startIndex, to: endIndex, by: chunkSize).map {
            Data(self[$0..<Swift.min($0 + chunkSize, endIndex)])
        }
    }
}
